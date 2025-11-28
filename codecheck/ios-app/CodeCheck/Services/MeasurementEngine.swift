import Foundation
import ARKit
import RealityKit
import Combine

class MeasurementEngine: NSObject, ObservableObject {
    let arView: ARView
    private var configuration: ARWorldTrackingConfiguration
    let isSupported: Bool

    @Published var isPlacingPoints = false
    @Published var currentDistance: Double?
    @Published var showingError = false
    @Published var measurementType: MeasurementType = .custom

    private var startPoint: SIMD3<Float>?
    private var endPoint: SIMD3<Float>?
    private var lineEntity: ModelEntity?

    override init() {
        self.arView = ARView(frame: .zero)
        self.configuration = ARWorldTrackingConfiguration()
        self.isSupported = ARWorldTrackingConfiguration.isSupported

        super.init()

        if isSupported {
            setupARSession()
            setupGestures()
        } else {
            showingError = true
        }
    }

    private func setupARSession() {
        // Check ARKit availability
        // Configure AR session
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        // Enable LiDAR if available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }

        arView.session.run(configuration)
        arView.session.delegate = self
    }

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isSupported, isPlacingPoints else { return }

        let location = gesture.location(in: arView)

        // Perform raycast to find real-world position
        let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any)

        guard let firstResult = results.first else {
            // Fallback to feature points if plane detection fails
            performFeaturePointRaycast(at: location)
            return
        }

        let position = SIMD3<Float>(
            firstResult.worldTransform.columns.3.x,
            firstResult.worldTransform.columns.3.y,
            firstResult.worldTransform.columns.3.z
        )

        placePoint(at: position)
    }

    private func performFeaturePointRaycast(at location: CGPoint) {
        // Get camera transform
        guard arView.session.currentFrame != nil else { return }

        // Try to create a raycast query for existing plane geometry
        if let query = arView.makeRaycastQuery(from: location, 
                                               allowing: .existingPlaneGeometry, 
                                               alignment: .any) {
            performRaycast(with: query)
            return
        }
        
        // If plane geometry isn't available, try estimated planes
        if let estimatedQuery = arView.makeRaycastQuery(from: location, 
                                                        allowing: .estimatedPlane, 
                                                        alignment: .any) {
            performRaycast(with: estimatedQuery)
        }
    }
    
    private func performRaycast(with query: ARRaycastQuery) {
        let results = arView.session.raycast(query)
        
        if let result = results.first {
            let position = SIMD3<Float>(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
            placePoint(at: position)
        }
    }

    private func placePoint(at position: SIMD3<Float>) {
        if startPoint == nil {
            // Place first point
            startPoint = position
            addMarker(at: position, color: .green)
        } else if endPoint == nil {
            // Place second point
            endPoint = position
            addMarker(at: position, color: .red)

            // Calculate distance
            if let start = startPoint {
                calculateDistance(from: start, to: position)
                drawLine(from: start, to: position)
            }
        }
    }

    private func addMarker(at position: SIMD3<Float>, color: UIColor) {
        let sphere = MeshResource.generateSphere(radius: 0.01)
        var material = SimpleMaterial()
        material.color = .init(tint: color)

        let markerEntity = ModelEntity(mesh: sphere, materials: [material])
        markerEntity.position = position

        let anchor = AnchorEntity(world: position)
        anchor.addChild(markerEntity)
        arView.scene.addAnchor(anchor)
    }

    private func drawLine(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        // Remove existing line
        lineEntity?.removeFromParent()

        // Calculate midpoint and length
        let midpoint = (start + end) / 2
        let distance = simd_distance(start, end)

        // Create cylinder for line
        let cylinder = MeshResource.generateBox(width: 0.005, height: distance, depth: 0.005)
        var material = SimpleMaterial()
        material.color = .init(tint: .blue)

        lineEntity = ModelEntity(mesh: cylinder, materials: [material])
        lineEntity?.position = midpoint

        // Calculate rotation to align with points
        let direction = end - start
        let normalizedDirection = simd_normalize(direction)

        // Calculate rotation quaternion
        let up = SIMD3<Float>(0, 1, 0)
        let rotationAxis = simd_cross(up, normalizedDirection)
        let rotationAngle = acos(simd_dot(up, normalizedDirection))

        if simd_length(rotationAxis) > 0.001 {
            let rotation = simd_quatf(angle: rotationAngle, axis: simd_normalize(rotationAxis))
            lineEntity?.orientation = rotation
        }

        let anchor = AnchorEntity(world: midpoint)
        if let line = lineEntity {
            anchor.addChild(line)
            arView.scene.addAnchor(anchor)
        }
    }

    private func calculateDistance(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let distance = simd_distance(start, end)
        // Convert meters to inches
        let inches = distance * 39.3701
        currentDistance = Double(inches)
    }

    func startMeasuring() {
        guard isSupported else {
            showingError = true
            return
        }
        isPlacingPoints = true
        clear()
    }

    func clear() {
        startPoint = nil
        endPoint = nil
        currentDistance = nil
        lineEntity?.removeFromParent()
        lineEntity = nil

        // Remove all anchors
        arView.scene.anchors.removeAll()
    }

    func stopMeasuring() {
        isPlacingPoints = false
    }
}

// MARK: - ARSessionDelegate
extension MeasurementEngine: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed: \(error.localizedDescription)")
        showingError = true
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("AR Session was interrupted")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR Session interruption ended")
        // Reset tracking
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}
