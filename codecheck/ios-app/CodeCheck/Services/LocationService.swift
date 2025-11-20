import Foundation
import CoreLocation

class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var error: LocationError?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocationPermission() {
        authorizationStatus = locationManager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            error = .permissionDenied
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }
    }

    func getCurrentLocation() async throws -> CLLocation {
        requestLocationPermission()

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationManager.requestLocation()

            // Set up a timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                if self?.currentLocation == nil {
                    continuation.resume(throwing: LocationError.timeout)
                }
            }

            // Store continuation to be used by delegate
            self.locationContinuation = continuation
        }
    }

    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        if let continuation = locationContinuation {
            continuation.resume(returning: location)
            locationContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = .locationFailed(error)

        if let continuation = locationContinuation {
            continuation.resume(throwing: LocationError.locationFailed(error))
            locationContinuation = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .restricted, .denied:
            error = .permissionDenied
        default:
            error = nil
        }
    }
}

// MARK: - Location Errors
enum LocationError: LocalizedError {
    case permissionDenied
    case locationFailed(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied. Please enable location access in Settings."
        case .locationFailed(let error):
            return "Failed to get location: \(error.localizedDescription)"
        case .timeout:
            return "Location request timed out. Please try again."
        }
    }
}
