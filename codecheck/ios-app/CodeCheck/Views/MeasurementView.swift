import SwiftUI
import ARKit
import RealityKit

struct MeasurementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var measurementEngine = MeasurementEngine()
    @State private var selectedType: MeasurementType = .stairTread
    @State private var showingResults = false
    @State private var measurement: Measurement?

    let project: Project?

    var body: some View {
        NavigationStack {
            Group {
                if measurementEngine.isSupported {
                    ZStack {
                        // AR View
                        ARViewContainer(measurementEngine: measurementEngine)
                            .edgesIgnoringSafeArea(.all)

                        VStack {
                            // Top Controls
                            VStack(spacing: 16) {
                                // Measurement Type Picker
                                Picker("Type", selection: $selectedType) {
                                    ForEach(MeasurementType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)

                                // Instructions
                                if !measurementEngine.isPlacingPoints {
                                    InstructionCard(
                                        icon: "hand.tap.fill",
                                        text: "Tap 'Start Measuring' to begin"
                                    )
                                } else {
                                    InstructionCard(
                                        icon: "hand.point.up.left.fill",
                                        text: "Tap to place measurement points"
                                    )
                                }
                            }
                            .padding()

                            Spacer()

                            // Bottom Controls
                            VStack(spacing: 16) {
                                // Current Distance Display
                                if let distance = measurementEngine.currentDistance {
                                    Text(String(format: "%.2f inches", distance))
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(20)
                                }

                                // Action Buttons
                                HStack(spacing: 16) {
                                    if measurementEngine.isPlacingPoints {
                                        Button {
                                            measurementEngine.clear()
                                        } label: {
                                            Label("Clear", systemImage: "arrow.counterclockwise")
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color.red.opacity(0.8))
                                                .foregroundColor(.white)
                                                .cornerRadius(12)
                                        }

                                        Button {
                                            saveMeasurement()
                                        } label: {
                                            Label("Done", systemImage: "checkmark")
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color.green.opacity(0.8))
                                                .foregroundColor(.white)
                                                .cornerRadius(12)
                                        }
                                        .disabled(measurementEngine.currentDistance == nil)
                                    } else {
                                        Button {
                                            measurementEngine.startMeasuring()
                                            measurementEngine.measurementType = selectedType
                                        } label: {
                                            Label("Start Measuring", systemImage: "ruler")
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
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    UnsupportedARView {
                        dismiss()
                    }
                }
            }
            .navigationTitle("AR Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("ARKit Not Available", isPresented: $measurementEngine.showingError) {
                Button("OK") { dismiss() }
            } message: {
                Text("This device does not support ARKit or LiDAR functionality required for measurements.")
            }
            .sheet(isPresented: $showingResults) {
                if let measurement = measurement {
                    MeasurementResultView(measurement: measurement, project: project)
                }
            }
        }
    }

    private func saveMeasurement() {
        guard let distance = measurementEngine.currentDistance else { return }

        measurement = Measurement(
            type: selectedType,
            value: distance,
            unit: .inches
        )

        showingResults = true
        measurementEngine.clear()
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var measurementEngine: MeasurementEngine

    func makeUIView(context: Context) -> ARView {
        return measurementEngine.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

struct InstructionCard: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            Text(text)
                .font(.subheadline)

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct MeasurementResultView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectManager: ProjectManager
    let measurement: Measurement
    let project: Project?

    @State private var notes = ""
    @State private var isCheckingCompliance = false
    @State private var complianceResult: ComplianceResponse?

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurement Details") {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(measurement.type.rawValue)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Value")
                        Spacer()
                        Text(String(format: "%.2f %@", measurement.value, measurement.unit.rawValue))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }

                if let result = complianceResult {
                    Section("Compliance Check") {
                        HStack {
                            Image(systemName: result.compliant ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.compliant ? .green : .red)

                            Text(result.compliant ? "Compliant" : "Non-Compliant")
                                .font(.headline)
                        }

                        if let violations = result.violations, !violations.isEmpty {
                            ForEach(violations, id: \.self) { violation in
                                Label(violation, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                            }
                        }

                        if let explanation = result.explanation {
                            Text(explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    if project != nil {
                        Button("Check Compliance") {
                            checkCompliance()
                        }
                        .disabled(isCheckingCompliance)
                    }

                    Button("Save to Project") {
                        saveMeasurement()
                    }
                }
            }
            .navigationTitle("Measurement Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func checkCompliance() {
        // TODO: Implement compliance checking via API
        isCheckingCompliance = true
    }

    private func saveMeasurement() {
        var updatedMeasurement = measurement
        updatedMeasurement.notes = notes.isEmpty ? nil : notes

        if let project = project {
            projectManager.addMeasurement(updatedMeasurement, to: project)
        }

        dismiss()
    }
}

struct UnsupportedARView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arkit")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("AR Measurements Unavailable")
                .font(.title2)
                .fontWeight(.bold)

            Text("This device doesn't support the LiDAR-powered AR measurements required for CodeCheck. You can still use the app's project tracking and AI assistant features.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onDismiss) {
                Text("Back to Home")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

#Preview {
    MeasurementView(project: nil)
        .environmentObject(ProjectManager())
}


