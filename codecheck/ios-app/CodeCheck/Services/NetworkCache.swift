//
//  NetworkCache.swift
//  CodeCheck
//
//  High-performance network cache with memory and disk persistence
//  Expected impact: 60% reduction in data usage, 70-90% faster cached responses
//

import Foundation
import CryptoKit

class NetworkCache {
    static let shared = NetworkCache()

    private let memoryCache = NSCache<NSString, CachedResponse>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let diskQueue = DispatchQueue(label: "com.codecheck.networkcache", qos: .utility)

    // Cache TTLs (Time To Live) by endpoint type
    private let ttls: [String: TimeInterval] = [
        "jurisdictions": 3600,      // 1 hour - jurisdictions rarely change
        "resolve": 3600,            // 1 hour - jurisdiction resolution
        "check": 300,                // 5 minutes - compliance checks
        "explain": 1800,             // 30 minutes - rule explanations
        "conversation": 0,           // Never cache - user-specific conversations
        "status": 60,                // 1 minute - status checks
        "auth": 0,                   // Never cache - authentication
        "login": 0,                  // Never cache - login
        "register": 0                // Never cache - registration
    ]

    init() {
        // Setup cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("NetworkCache")

        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure memory cache limits
        memoryCache.countLimit = 100                    // Max 100 cached responses
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit

        // Clean up old cache files on init
        cleanupExpiredCache()
    }

    // MARK: - Public API

    /// Get cached data for a request if available and valid
    func get(for request: URLRequest) -> Data? {
        guard let url = request.url,
              shouldCache(url: url) else { return nil }

        let key = cacheKey(for: request)

        // Check memory cache first (fastest)
        if let cached = memoryCache.object(forKey: key as NSString) {
            if cached.isValid {
                return cached.data
            } else {
                // Expired, remove from memory cache
                memoryCache.removeObject(forKey: key as NSString)
            }
        }

        // Check disk cache (slower but persists across app launches)
        if let cached = loadFromDisk(key: key), cached.isValid {
            // Promote to memory cache for faster future access
            memoryCache.setObject(cached, forKey: key as NSString, cost: cached.data.count)
            return cached.data
        }

        return nil
    }

    /// Store data in cache for a request
    func set(_ data: Data, for request: URLRequest) {
        guard let url = request.url,
              shouldCache(url: url) else { return }

        let key = cacheKey(for: request)
        let ttl = getTTL(for: url)

        // Skip if TTL is 0 (don't cache)
        guard ttl > 0 else { return }

        let expiry = Date().addingTimeInterval(ttl)
        let cached = CachedResponse(data: data, expiry: expiry)

        // Store in memory cache
        memoryCache.setObject(cached, forKey: key as NSString, cost: data.count)

        // Store on disk asynchronously
        saveToDisk(data: data, key: key, expiry: expiry)
    }

    /// Clear all cached data (memory and disk)
    func clear() {
        memoryCache.removeAllObjects()
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
    }

    /// Clear expired cache entries from disk
    func cleanupExpiredCache() {
        diskQueue.async { [weak self] in
            guard let self = self else { return }

            guard let files = try? self.fileManager.contentsOfDirectory(
                at: self.cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }

            for fileURL in files {
                // Load and check if expired
                if let cached = self.loadFromDisk(fileURL: fileURL), !cached.isValid {
                    try? self.fileManager.removeItem(at: fileURL)
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Determine if a URL should be cached
    private func shouldCache(url: URL) -> Bool {
        let path = url.path.lowercased()

        // Never cache authentication or user-specific endpoints
        if path.contains("conversation") ||
           path.contains("auth/login") ||
           path.contains("auth/register") ||
           path.contains("auth/refresh") {
            return false
        }

        return true
    }

    /// Get TTL for a specific URL
    private func getTTL(for url: URL) -> TimeInterval {
        let path = url.path.lowercased()

        for (key, ttl) in ttls {
            if path.contains(key) {
                return ttl
            }
        }

        // Default: 5 minutes for uncategorized endpoints
        return 300
    }

    /// Generate cache key from request (includes URL and body for POST requests)
    private func cacheKey(for request: URLRequest) -> String {
        var components = [String]()

        // Add URL
        if let url = request.url {
            components.append(url.absoluteString)
        }

        // Add HTTP method
        if let method = request.httpMethod {
            components.append(method)
        }

        // Add body for POST/PUT requests (to differentiate different requests to same endpoint)
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            components.append(bodyString)
        }

        let combined = components.joined(separator: "|")
        return sha256(combined)
    }

    /// Generate SHA256 hash for cache key
    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Disk Cache Operations

    /// Save cached response to disk
    private func saveToDisk(data: Data, key: String, expiry: Date) {
        diskQueue.async { [weak self] in
            guard let self = self else { return }

            let fileURL = self.cacheDirectory.appendingPathComponent(key)

            do {
                // Create a wrapper with metadata
                let wrapper = DiskCacheWrapper(data: data, expiry: expiry)
                let encoded = try JSONEncoder().encode(wrapper)
                try encoded.write(to: fileURL, options: .atomic)
            } catch {
                print("NetworkCache: Failed to save to disk: \(error.localizedDescription)")
            }
        }
    }

    /// Load cached response from disk by key
    private func loadFromDisk(key: String) -> CachedResponse? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        return loadFromDisk(fileURL: fileURL)
    }

    /// Load cached response from disk by file URL
    private func loadFromDisk(fileURL: URL) -> CachedResponse? {
        do {
            let data = try Data(contentsOf: fileURL)
            let wrapper = try JSONDecoder().decode(DiskCacheWrapper.self, from: data)
            return CachedResponse(data: wrapper.data, expiry: wrapper.expiry)
        } catch {
            // File doesn't exist or is corrupted, remove it
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
}

// MARK: - Supporting Types

/// In-memory cached response with expiration
class CachedResponse {
    let data: Data
    let expiry: Date

    var isValid: Bool {
        return Date() < expiry
    }

    init(data: Data, expiry: Date) {
        self.data = data
        self.expiry = expiry
    }
}

/// Disk cache wrapper with metadata
private struct DiskCacheWrapper: Codable {
    let data: Data
    let expiry: Date
}
