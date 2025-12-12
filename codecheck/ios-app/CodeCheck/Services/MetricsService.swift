//
//  MetricsService.swift
//  CodeCheck
//
//  Lightweight metrics collection for cache and network performance
//  Simplified to track only essential metrics that aid debugging
//

import Foundation

/// Lightweight metrics service for cache and network performance
/// Thread-safe actor for collecting essential performance metrics
actor MetricsService {
    static let shared = MetricsService()

    // MARK: - Cache Metrics

    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var cacheEvictions: Int = 0

    // MARK: - Network Metrics

    private var networkRequests: Int = 0
    private var networkErrors: Int = 0

    // MARK: - Initialization

    private init() {
        loadPersistedMetrics()
    }

    // MARK: - Cache Recording

    func recordCacheHit() {
        cacheHits += 1
    }

    func recordCacheMiss() {
        cacheMisses += 1
    }

    func recordCacheEviction() {
        cacheEvictions += 1
    }

    // MARK: - Network Recording

    func recordNetworkRequest(success: Bool) {
        networkRequests += 1
        if !success {
            networkErrors += 1
        }
    }

    // MARK: - Summary

    /// Get a summary of current metrics
    func getSummary() -> MetricsSummary {
        let cacheTotal = cacheHits + cacheMisses
        let cacheHitRate = cacheTotal > 0 ? Double(cacheHits) / Double(cacheTotal) : 0
        let errorRate = networkRequests > 0 ? Double(networkErrors) / Double(networkRequests) : 0

        return MetricsSummary(
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            cacheHitRate: cacheHitRate,
            cacheEvictions: cacheEvictions,
            networkRequests: networkRequests,
            networkErrors: networkErrors,
            errorRate: errorRate
        )
    }

    // MARK: - Reset

    func resetMetrics() {
        cacheHits = 0
        cacheMisses = 0
        cacheEvictions = 0
        networkRequests = 0
        networkErrors = 0
        clearPersistedMetrics()
    }

    // MARK: - Persistence

    private let metricsKey = "codecheck_metrics_v2"

    private func loadPersistedMetrics() {
        guard let data = UserDefaults.standard.data(forKey: metricsKey),
              let persisted = try? JSONDecoder().decode(PersistedMetrics.self, from: data) else {
            return
        }

        cacheHits = persisted.cacheHits
        cacheMisses = persisted.cacheMisses
        cacheEvictions = persisted.cacheEvictions
        networkRequests = persisted.networkRequests
        networkErrors = persisted.networkErrors
    }

    func persistMetrics() {
        let persisted = PersistedMetrics(
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            cacheEvictions: cacheEvictions,
            networkRequests: networkRequests,
            networkErrors: networkErrors
        )

        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: metricsKey)
        }
    }

    private func clearPersistedMetrics() {
        UserDefaults.standard.removeObject(forKey: metricsKey)
    }
}

// MARK: - Supporting Types

struct MetricsSummary: Codable {
    let cacheHits: Int
    let cacheMisses: Int
    let cacheHitRate: Double
    let cacheEvictions: Int
    let networkRequests: Int
    let networkErrors: Int
    let errorRate: Double

    // Formatted helpers
    var formattedCacheHitRate: String {
        String(format: "%.1f%%", cacheHitRate * 100)
    }

    var formattedErrorRate: String {
        String(format: "%.1f%%", errorRate * 100)
    }
}

private struct PersistedMetrics: Codable {
    let cacheHits: Int
    let cacheMisses: Int
    let cacheEvictions: Int
    let networkRequests: Int
    let networkErrors: Int
}
