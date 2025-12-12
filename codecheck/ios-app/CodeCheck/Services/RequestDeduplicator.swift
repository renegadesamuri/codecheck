//
//  RequestDeduplicator.swift
//  CodeCheck
//
//  Phase 3 Optimization: Request Deduplication
//  Prevents duplicate concurrent requests to the same endpoint
//

import Foundation
import CryptoKit

/// Actor that manages in-flight request deduplication
/// When multiple identical requests are made concurrently, only one network call is made
/// and all callers receive the same result
actor RequestDeduplicator {
    static let shared = RequestDeduplicator()

    /// Pending requests keyed by their unique identifier
    private var pendingRequests: [String: Task<Data, Error>] = [:]

    /// Statistics for monitoring
    private var deduplicatedCount: Int = 0
    private var totalRequests: Int = 0

    private init() {}

    /// Execute a request with deduplication
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - session: The URLSession to use (defaults to NetworkManager.shared.session)
    /// - Returns: The response data
    func execute(
        request: URLRequest,
        using session: URLSession = NetworkManager.shared.session
    ) async throws -> Data {
        let key = generateKey(for: request)
        totalRequests += 1

        // Check if identical request is already in-flight
        if let existingTask = pendingRequests[key] {
            deduplicatedCount += 1
            return try await existingTask.value
        }

        // Create new task for this request
        let task = Task<Data, Error> {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.init(rawValue: httpResponse.statusCode))
            }

            return data
        }

        pendingRequests[key] = task

        defer {
            pendingRequests.removeValue(forKey: key)
        }

        return try await task.value
    }

    /// Execute a request with deduplication and custom response handling
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - session: The URLSession to use
    ///   - responseHandler: Custom handler for the response
    /// - Returns: The response data
    func executeWithResponse(
        request: URLRequest,
        using session: URLSession = NetworkManager.shared.session
    ) async throws -> (Data, HTTPURLResponse) {
        let key = generateKey(for: request)

        // For requests that need response headers, we can't fully deduplicate
        // but we can still prevent truly duplicate calls
        if let existingTask = pendingRequests[key] {
            deduplicatedCount += 1
            let data = try await existingTask.value
            // Return a synthetic response since we deduplicated
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        }

        let task = Task<Data, Error> {
            let (data, _) = try await session.data(for: request)
            return data
        }

        pendingRequests[key] = task

        defer {
            pendingRequests.removeValue(forKey: key)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return (data, httpResponse)
    }

    /// Generate a unique key for a request based on URL, method, and body
    private func generateKey(for request: URLRequest) -> String {
        var components: [String] = []

        // Include HTTP method
        components.append(request.httpMethod ?? "GET")

        // Include URL
        if let url = request.url?.absoluteString {
            components.append(url)
        }

        // Include body for POST/PUT requests
        if let body = request.httpBody {
            let bodyHash = SHA256.hash(data: body)
            let hashString = bodyHash.compactMap { String(format: "%02x", $0) }.joined()
            components.append(hashString)
        }

        // Create combined hash
        let combined = components.joined(separator: "|")
        let combinedData = Data(combined.utf8)
        let hash = SHA256.hash(data: combinedData)

        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Get current deduplication statistics
    func getStats() -> (total: Int, deduplicated: Int, hitRate: Double) {
        let hitRate = totalRequests > 0 ? Double(deduplicatedCount) / Double(totalRequests) : 0
        return (totalRequests, deduplicatedCount, hitRate)
    }

    /// Reset statistics
    func resetStats() {
        deduplicatedCount = 0
        totalRequests = 0
    }

    /// Check if a request is currently in-flight
    func isRequestPending(for request: URLRequest) -> Bool {
        let key = generateKey(for: request)
        return pendingRequests[key] != nil
    }

    /// Get count of currently pending requests
    var pendingCount: Int {
        pendingRequests.count
    }
}

// MARK: - Convenience Extension for URLRequest

extension URLRequest {
    /// Execute this request with deduplication
    func executeWithDeduplication(
        using session: URLSession = NetworkManager.shared.session
    ) async throws -> Data {
        try await RequestDeduplicator.shared.execute(request: self, using: session)
    }
}
