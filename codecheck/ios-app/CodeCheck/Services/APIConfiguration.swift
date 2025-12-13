import Foundation

/// Configuration manager for API endpoints
/// Supports development, staging, and production environments
class APIConfiguration {
    
    static let shared = APIConfiguration()
    
    // MARK: - Environment
    
    enum Environment: String {
        case development = "Development"
        case staging = "Staging"
        case production = "Production"
        case custom = "Custom"
    }
    
    // MARK: - Current Environment
    
    /// The active environment - change this for different builds
    private(set) var currentEnvironment: Environment
    
    init() {
        // Default to production for release builds, development for debug
        #if DEBUG
        self.currentEnvironment = .development
        #else
        self.currentEnvironment = .production
        #endif
        
        // Check for custom server override from settings
        if UserDefaults.standard.bool(forKey: "useCustomServer"),
           let customURL = UserDefaults.standard.string(forKey: "customServerURL"),
           !customURL.isEmpty {
            self.currentEnvironment = .custom
        }
    }
    
    // MARK: - Base URLs
    
    var baseURL: String {
        // Custom URL takes precedence
        if currentEnvironment == .custom,
           let customURL = UserDefaults.standard.string(forKey: "customServerURL") {
            return customURL
        }
        
        switch currentEnvironment {
        case .development:
            return developmentURL
        case .staging:
            return stagingURL
        case .production:
            return productionURL
        case .custom:
            return developmentURL // Fallback
        }
    }
    
    // MARK: - Environment URLs
    
    /// Development: Local backend for testing
    private var developmentURL: String {
        #if targetEnvironment(simulator)
        return "http://localhost:8000"
        #else
        // For physical device during development
        // TODO: Update this with your Mac's IP when testing on device
        return "http://10.0.0.214:8000"
        #endif
    }
    
    /// Staging: For testing in production-like environment
    /// Deploy a staging backend to test before going live
    private var stagingURL: String {
        return "https://codecheck-staging.onrender.com"  // TODO: Update with your staging URL
    }
    
    /// Production: Live backend for all users
    private var productionURL: String {
        // TODO: IMPORTANT - Update this before releasing to App Store!
        // This is what all users will connect to
        return "https://codecheck-api.onrender.com"  // TODO: Update with your production URL
    }
    
    // MARK: - Configuration Methods
    
    /// Switch to a different environment
    func setEnvironment(_ environment: Environment) {
        self.currentEnvironment = environment
        NotificationCenter.default.post(name: .apiEnvironmentChanged, object: nil)
    }
    
    /// Check if currently in development mode
    var isDevelopment: Bool {
        return currentEnvironment == .development
    }
    
    /// Check if currently in production mode
    var isProduction: Bool {
        return currentEnvironment == .production
    }
    
    // MARK: - Debug Information
    
    /// Get debug info about current configuration
    var debugInfo: String {
        """
        Environment: \(currentEnvironment.rawValue)
        Base URL: \(baseURL)
        Build: \(isDevelopment ? "Debug" : "Release")
        Simulator: \(targetEnvironment == "simulator")
        """
    }
    
    private var targetEnvironment: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "device"
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let apiEnvironmentChanged = Notification.Name("apiEnvironmentChanged")
}

// MARK: - Helper Extension

extension APIConfiguration {
    /// Convenience method to test if a URL is reachable
    func testConnection() async -> (success: Bool, message: String) {
        guard let url = URL(string: baseURL) else {
            return (false, "Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Invalid response")
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                return (true, "Connected to \(currentEnvironment.rawValue)")
            } else {
                return (false, "Server responded with status \(httpResponse.statusCode)")
            }
        } catch {
            return (false, "Connection failed: \(error.localizedDescription)")
        }
    }
}
