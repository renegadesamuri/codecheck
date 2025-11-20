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
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var selectedViolationForExplanation: ComplianceViolation?
    @State private var explanation: String?
    @State private var isLoadingExplanation = false

    private let codeLookupService = CodeLookupService()
    private let locationService = LocationService()

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
                    Section {
                        HStack {
                            Image(systemName: result.isCompliant ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.isCompliant ? .green : .red)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.isCompliant ? "Compliant" : "Non-Compliant")
                                    .font(.headline)

                                Text(String(format: "Confidence: %.0f%%", result.confidence * 100))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        if let violations = result.violations, !violations.isEmpty {
                            ForEach(violations, id: \.self) { violation in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        Text(violation.message)
                                            .font(.subheadline)
                                    }

                                    Text("Section: \(violation.sectionRef)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Button {
                                        selectedViolationForExplanation = violation
                                        explainViolation(violation)
                                    } label: {
                                        HStack {
                                            Image(systemName: "lightbulb.fill")
                                            Text("Explain Rule")
                                        }
                                        .font(.caption)
                                    }
                                    .disabled(isLoadingExplanation)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        if let recommendations = result.recommendations, !recommendations.isEmpty {
                            ForEach(recommendations, id: \.self) { recommendation in
                                Label(recommendation, systemImage: "lightbulb.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        }

                        if let explanation = explanation {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("AI Explanation")
                                    .font(.headline)
                                Text(explanation)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Compliance Check")
                    }
                }

                Section {
                    if project != nil {
                        Button {
                            Task {
                                await checkCompliance()
                            }
                        } label: {
                            HStack {
                                if isCheckingCompliance {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                }
                                Text("Check Compliance")
                            }
                        }
                        .disabled(isCheckingCompliance)
                    }

                    Button("Save to Project") {
                        saveMeasurement()
                    }
                    .disabled(isCheckingCompliance)
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
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    errorMessage = nil
                }
                if errorMessage?.contains("Authentication") == true {
                    Button("Go to Login") {
                        // TODO: Navigate to login
                    }
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func checkCompliance() async {
        isCheckingCompliance = true
        errorMessage = nil
        explanation = nil

        do {
            // Step 1: Get current location
            guard let project = project,
                  let latitude = project.latitude,
                  let longitude = project.longitude else {
                // Fallback to device location
                let location = try await locationService.getCurrentLocation()
                await performComplianceCheck(latitude: location.coordinate.latitude,
                                            longitude: location.coordinate.longitude)
                return
            }

            // Use project location
            await performComplianceCheck(latitude: latitude, longitude: longitude)

        } catch let error as LocationError {
            errorMessage = error.errorDescription
            showError = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            showError = true
        }

        isCheckingCompliance = false
    }

    private func performComplianceCheck(latitude: Double, longitude: Double) async {
        do {
            // Step 2: Resolve jurisdiction
            let jurisdictions = try await codeLookupService.resolveJurisdiction(
                latitude: latitude,
                longitude: longitude
            )

            guard let jurisdiction = jurisdictions.first else {
                throw APIError.noJurisdictionFound
            }

            // Step 3: Convert measurement to API format
            let metricKey = measurementTypeToAPIKey(measurement.type)
            let metrics = [metricKey: measurement.value]

            // Step 4: Check compliance
            let result = try await codeLookupService.checkCompliance(
                jurisdictionId: jurisdiction.id,
                metrics: metrics
            )

            // Update UI on main thread
            await MainActor.run {
                complianceResult = result
            }

        } catch let error as APIError {
            await MainActor.run {
                errorMessage = error.errorDescription
                showError = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to check compliance: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    private func explainViolation(_ violation: ComplianceViolation) {
        isLoadingExplanation = true
        explanation = nil

        Task {
            do {
                let explainResponse = try await codeLookupService.explainRule(
                    ruleId: violation.ruleId,
                    measurementValue: measurement.value
                )

                await MainActor.run {
                    explanation = explainResponse.explanation
                    isLoadingExplanation = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                    showError = true
                    isLoadingExplanation = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to get explanation: \(error.localizedDescription)"
                    showError = true
                    isLoadingExplanation = false
                }
            }
        }
    }

    private func measurementTypeToAPIKey(_ type: MeasurementType) -> String {
        switch type {
        case .stairTread:
            return "stair_tread_in"
        case .stairRiser:
            return "stair_riser_in"
        case .doorWidth:
            return "door_width_in"
        case .railingHeight:
            return "railing_height_in"
        case .ceilingHeight:
            return "ceiling_height_in"
        case .custom:
            return "custom_in"
        }
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


