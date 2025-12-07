import SwiftUI
import ARKit
import RealityKit

struct MeasurementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var measurementEngine = MeasurementEngine()
    @State private var selectedType: MeasurementType = .stairTread
    @State private var showingResults = false
    @State private var measurement: Measurement?
    @State private var showingSettings = false

    let project: Project?

    var body: some View {
        NavigationStack {
            Group {
                if measurementEngine.isSupported {
                    ZStack {
                        // AR View
                        ARViewContainer(measurementEngine: measurementEngine)
                            .edgesIgnoringSafeArea(.all)

                        // Crosshair overlay when measuring
                        if measurementEngine.measurementState.isPlacingPoints && measurementEngine.measurementState.currentDistance == nil {
                            CrosshairOverlay()
                        }

                        VStack(spacing: 0) {
                            // Top Controls
                            TopControlsView(
                                selectedType: $selectedType,
                                measurementEngine: measurementEngine,
                                showingSettings: $showingSettings
                            )

                            Spacer()

                            // Live Preview Distance (shows while aiming)
                            if let previewDistance = measurementEngine.measurementState.livePreviewDistance,
                               measurementEngine.measurementState.currentDistance == nil {
                                LivePreviewCard(distance: previewDistance)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                    .animation(.easeOut(duration: 0.15), value: previewDistance)
                            }

                            Spacer()

                            // Bottom Controls
                            BottomControlsView(
                                measurementEngine: measurementEngine,
                                selectedType: $selectedType,
                                onDone: saveMeasurement
                            )
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
            .alert("ARKit Not Available", isPresented: $measurementEngine.measurementState.showingError) {
                Button("OK") { dismiss() }
            } message: {
                Text("This device does not support ARKit or LiDAR functionality required for measurements.")
            }
            .sheet(isPresented: $showingResults) {
                if let measurement = measurement {
                    MeasurementResultView(measurement: measurement, project: project)
                }
            }
            .sheet(isPresented: $showingSettings) {
                MeasurementSettingsSheet(measurementEngine: measurementEngine)
            }
        }
    }

    private func saveMeasurement() {
        guard let distance = measurementEngine.measurementState.currentDistance else { return }

        measurement = Measurement(
            type: selectedType,
            value: distance,
            unit: .inches
        )

        showingResults = true
        measurementEngine.clear()
    }
}

// MARK: - Crosshair Overlay

struct CrosshairOverlay: View {
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                .frame(width: 60, height: 60)
                .scaleEffect(scale)

            // Inner crosshair
            Group {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 20, height: 1.5)

                Rectangle()
                    .fill(Color.white)
                    .frame(width: 1.5, height: 20)
            }

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
        }
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                scale = 1.1
            }
        }
    }
}

// MARK: - Top Controls

struct TopControlsView: View {
    @Binding var selectedType: MeasurementType
    @ObservedObject var measurementEngine: MeasurementEngine
    @Binding var showingSettings: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Tracking Quality Indicator
            TrackingQualityBadge(quality: measurementEngine.trackingState.quality)

            HStack(spacing: 12) {
                // Measurement Type Picker
                Menu {
                    ForEach(MeasurementType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                            measurementEngine.measurementType = type
                        } label: {
                            HStack {
                                Text(type.rawValue)
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: iconForType(selectedType))
                            .font(.body)
                        Text(selectedType.rawValue)
                            .font(.subheadline.weight(.medium))
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }

                Spacer()

                // Settings button
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }

            // Instruction Card
            InstructionCard(
                icon: instructionIcon,
                text: measurementEngine.trackingState.instructionMessage,
                isAutoDetecting: measurementEngine.detectionState.isAutoDetecting
            )
        }
        .padding()
    }

    private var instructionIcon: String {
        if measurementEngine.detectionState.isAutoDetecting {
            return "sparkles"
        } else if !measurementEngine.measurementState.isPlacingPoints {
            return "hand.tap.fill"
        } else if measurementEngine.measurementState.currentDistance != nil {
            return "checkmark.circle.fill"
        } else {
            return "hand.point.up.left.fill"
        }
    }

    private func iconForType(_ type: MeasurementType) -> String {
        switch type {
        case .stairTread: return "stairs"
        case .stairRiser: return "arrow.up.square"
        case .doorWidth: return "door.left.hand.open"
        case .railingHeight: return "rectangle.portrait.arrowtriangle.2.inward"
        case .ceilingHeight: return "arrow.up.to.line"
        case .custom: return "ruler"
        }
    }
}

// MARK: - Tracking Quality Badge

struct TrackingQualityBadge: View {
    let quality: MeasurementEngine.TrackingQuality

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(qualityColor)
                .frame(width: 8, height: 8)

            Text(quality.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var qualityColor: Color {
        switch quality {
        case .notAvailable: return .red
        case .limited: return .orange
        case .normal: return .green
        }
    }
}

// MARK: - Live Preview Card

struct LivePreviewCard: View {
    let distance: Double

    var body: some View {
        VStack(spacing: 4) {
            Text("Preview")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(String(format: "%.1f\"", distance))
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Bottom Controls

struct BottomControlsView: View {
    @ObservedObject var measurementEngine: MeasurementEngine
    @Binding var selectedType: MeasurementType
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Final Distance Display with Confidence
            if let distance = measurementEngine.measurementState.currentDistance {
                FinalMeasurementCard(
                    distance: distance,
                    confidence: measurementEngine.measurementState.measurementConfidence
                )
                .transition(.scale.combined(with: .opacity))
            }

            // Action Buttons
            HStack(spacing: 12) {
                if measurementEngine.measurementState.isPlacingPoints {
                    // Undo Button
                    Button {
                        measurementEngine.undoLastPoint()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title3)
                            .frame(width: 50, height: 50)
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }

                    // Clear Button
                    Button {
                        measurementEngine.clear()
                    } label: {
                        Label("Clear", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    // Done Button
                    Button {
                        onDone()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(measurementEngine.measurementState.currentDistance != nil ? Color.green : Color.green.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .disabled(measurementEngine.measurementState.currentDistance == nil)
                } else {
                    // Start Measuring Button
                    Button {
                        measurementEngine.startMeasuring()
                        measurementEngine.measurementType = selectedType
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "ruler")
                                .font(.title2)
                            Text("Start Measuring")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
            }

            // Gesture hints
            if measurementEngine.measurementState.isPlacingPoints {
                GestureHintsView()
            }
        }
        .padding()
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: measurementEngine.measurementState.isPlacingPoints)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: measurementEngine.measurementState.currentDistance)
    }
}

// MARK: - Final Measurement Card

struct FinalMeasurementCard: View {
    let distance: Double
    let confidence: Float

    var body: some View {
        VStack(spacing: 8) {
            // Main distance
            Text(String(format: "%.2f", distance))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            +
            Text(" in")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            // Confidence indicator
            ConfidenceIndicator(confidence: confidence)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
    }
}

// MARK: - Confidence Indicator

struct ConfidenceIndicator: View {
    let confidence: Float

    var body: some View {
        HStack(spacing: 8) {
            // Confidence bars
            HStack(spacing: 3) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < Int(confidence * 5) ? confidenceColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 16 + CGFloat(index * 2))
                }
            }

            Text(confidenceText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }

    private var confidenceText: String {
        if confidence >= 0.8 {
            return "High accuracy"
        } else if confidence >= 0.5 {
            return "Good accuracy"
        } else {
            return "Low accuracy"
        }
    }
}

// MARK: - Gesture Hints

struct GestureHintsView: View {
    var body: some View {
        HStack(spacing: 16) {
            HintBadge(icon: "hand.tap", text: "Tap to place")
            HintBadge(icon: "hand.tap.fill", text: "2x tap to clear")
            HintBadge(icon: "hand.draw", text: "Hold for edges")
        }
        .padding(.top, 8)
    }
}

struct HintBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Settings Sheet

struct MeasurementSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var measurementEngine: MeasurementEngine
    @State private var edgeDetectionEnabled = true
    @State private var hapticFeedbackEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Auto-Detection") {
                    Toggle("Edge Detection", isOn: $edgeDetectionEnabled)
                        .onChange(of: edgeDetectionEnabled) { _, newValue in
                            measurementEngine.toggleEdgeDetection(newValue)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Snap Distance")
                        Text("Points will snap to detected edges within this range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Feedback") {
                    Toggle("Haptic Feedback", isOn: $hapticFeedbackEnabled)
                }

                Section("Tips") {
                    TipRow(icon: "hand.draw.fill", title: "Long Press", description: "Hold to see detected edges and corners")
                    TipRow(icon: "hand.tap.fill", title: "Double Tap", description: "Quickly clear all points")
                    TipRow(icon: "arrow.uturn.backward", title: "Undo", description: "Remove the last placed point")
                    TipRow(icon: "move.3d", title: "Move Slowly", description: "Slower movement improves accuracy")
                }
            }
            .navigationTitle("Measurement Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AR View Container

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var measurementEngine: MeasurementEngine

    func makeUIView(context: Context) -> ARView {
        return measurementEngine.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

// MARK: - Instruction Card

struct InstructionCard: View {
    let icon: String
    let text: String
    var isAutoDetecting: Bool = false

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if isAutoDetecting {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .scaleEffect(isAnimating ? 1.3 : 1.0)
                        .opacity(isAnimating ? 0 : 1)
                }

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isAutoDetecting ? .cyan : .blue)
            }
            .frame(width: 36, height: 36)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .onAppear {
            if isAutoDetecting {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
        }
        .onChange(of: isAutoDetecting) { _, newValue in
            if newValue {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            } else {
                isAnimating = false
            }
        }
    }
}

// MARK: - Measurement Result View

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
    @State private var isLoadingCodes = false
    @State private var loadingProgress: Int = 0
    @State private var loadingMessage: String = ""
    @State private var loadingTask: Task<Void, Error>?

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

                if isLoadingCodes {
                    Section {
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Loading Building Codes")
                                        .font(.headline)

                                    Text(loadingMessage)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)

                            // Progress Bar
                            VStack(spacing: 8) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 20)

                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: geometry.size.width * CGFloat(loadingProgress) / 100.0, height: 20)
                                            .animation(.easeInOut(duration: 0.3), value: loadingProgress)
                                    }
                                }
                                .frame(height: 20)

                                HStack {
                                    Text("\(loadingProgress)%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }

                            Button(role: .destructive) {
                                cancelLoading()
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text("Cancel")
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Code Loading Progress")
                    }
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

            // Step 3: Check if codes are loaded
            let status = try await codeLookupService.checkJurisdictionStatus(
                jurisdictionId: jurisdiction.id
            )

            switch status.status {
            case "ready":
                // Codes available, proceed with compliance check
                break

            case "loading":
                // Show loading progress
                await MainActor.run {
                    isLoadingCodes = true
                    loadingProgress = status.progress ?? 0
                    loadingMessage = "Loading building codes for \(jurisdiction.name)..."
                }

                // Poll for completion
                try await pollForCompletion(jurisdictionId: jurisdiction.id, jurisdictionName: jurisdiction.name)

            case "not_loaded":
                // Trigger loading
                await MainActor.run {
                    isLoadingCodes = true
                    loadingProgress = 0
                    loadingMessage = "Initiating code download for \(jurisdiction.name)..."
                }

                _ = try await codeLookupService.triggerCodeLoading(
                    jurisdictionId: jurisdiction.id
                )

                await MainActor.run {
                    loadingMessage = "Loading building codes. This may take 30-60 seconds..."
                }

                // Poll for completion
                try await pollForCompletion(jurisdictionId: jurisdiction.id, jurisdictionName: jurisdiction.name)

            default:
                break
            }

            // Step 4: Convert measurement to API format
            let metricKey = measurementTypeToAPIKey(measurement.type)
            let metrics = [metricKey: measurement.value]

            // Step 5: Check compliance
            let result = try await codeLookupService.checkCompliance(
                jurisdictionId: jurisdiction.id,
                metrics: metrics
            )

            // Update UI on main thread
            await MainActor.run {
                complianceResult = result
                isLoadingCodes = false
                loadingProgress = 0
                loadingMessage = ""
            }

        } catch let error as APIError {
            await MainActor.run {
                errorMessage = error.errorDescription
                showError = true
                isLoadingCodes = false
                loadingProgress = 0
                loadingMessage = ""
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to check compliance: \(error.localizedDescription)"
                showError = true
                isLoadingCodes = false
                loadingProgress = 0
                loadingMessage = ""
            }
        }
    }

    private func pollForCompletion(jurisdictionId: String, jurisdictionName: String) async throws {
        var attempts = 0
        let maxAttempts = 60  // 60 seconds max

        loadingTask = Task {
            while attempts < maxAttempts {
                // Check if task was cancelled
                if Task.isCancelled {
                    throw CancellationError()
                }

                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

                do {
                    let status = try await codeLookupService.checkJurisdictionStatus(
                        jurisdictionId: jurisdictionId
                    )

                    await MainActor.run {
                        if let progress = status.progress {
                            loadingProgress = progress
                        }
                        loadingMessage = status.message
                    }

                    if status.status == "ready" {
                        await MainActor.run {
                            loadingMessage = "Building codes loaded successfully!"
                        }
                        return
                    }

                    attempts += 1
                } catch {
                    // If polling fails, continue trying
                    attempts += 1
                }
            }

            // Timeout reached
            throw APIError.timeout
        }

        try await loadingTask?.value
    }

    private func cancelLoading() {
        loadingTask?.cancel()
        isLoadingCodes = false
        loadingProgress = 0
        loadingMessage = ""
        isCheckingCompliance = false
        errorMessage = "Code loading cancelled by user"
        showError = true
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

// MARK: - Unsupported AR View

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
