//
//  RetryHandler.swift
//  CodeCheck
//
//  Automatic retry logic for network requests with exponential backoff
//

import Foundation

class RetryHandler {
    
    // MARK: - Configuration
    
    struct Configuration {
        let maxRetries: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double
        
        static let `default` = Configuration(
            maxRetries: 3,
            initialDelay: 0.5,
            maxDelay: 5.0,
            multiplier: 2.0
        )
        
        static let conservative = Configuration(
            maxRetries: 2,
            initialDelay: 1.0,
            maxDelay: 3.0,
            multiplier: 1.5
        )
        
        static let aggressive = Configuration(
            maxRetries: 5,
            initialDelay: 0.25,
            maxDelay: 10.0,
            multiplier: 2.5
        )
    }
    
    // MARK: - Public Methods
    
    /// Execute a network request with automatic retry and exponential backoff
    static func executeRequest(
        _ request: URLRequest,
        using session: URLSession,
        config: Configuration = .default
    ) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?
        var attempt = 0
        
        while attempt <= config.maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw RetryError.invalidResponse
                }
                
                // Check if we should retry based on status code
                if shouldRetry(statusCode: httpResponse.statusCode) && attempt < config.maxRetries {
                    attempt += 1
                    let delay = calculateDelay(attempt: attempt, config: config)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                return (data, httpResponse)
                
            } catch {
                lastError = error
                
                // Check if we should retry based on error type
                if shouldRetry(error: error) && attempt < config.maxRetries {
                    attempt += 1
                    let delay = calculateDelay(attempt: attempt, config: config)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                // If we shouldn't retry or we're out of retries, throw the error
                throw error
            }
        }
        
        // If we exhausted all retries, throw the last error
        throw lastError ?? RetryError.maxRetriesExceeded
    }
    
    /// Execute a generic async operation with retry logic
    static func execute<T>(
        with config: Configuration = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0
        
        while attempt <= config.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if shouldRetry(error: error) && attempt < config.maxRetries {
                    attempt += 1
                    let delay = calculateDelay(attempt: attempt, config: config)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                throw error
            }
        }
        
        throw lastError ?? RetryError.maxRetriesExceeded
    }
    
    // MARK: - Private Helpers
    
    private static func shouldRetry(statusCode: Int) -> Bool {
        // Retry on server errors (5xx) and some client errors
        switch statusCode {
        case 408, 429, 500...599:
            return true
        default:
            return false
        }
    }
    
    private static func shouldRetry(error: Error) -> Bool {
        // Retry on network errors, timeouts, etc.
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .cannotConnectToHost,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .dnsLookupFailed,
                 .cannotFindHost:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private static func calculateDelay(attempt: Int, config: Configuration) -> TimeInterval {
        let delay = config.initialDelay * pow(config.multiplier, Double(attempt - 1))
        return min(delay, config.maxDelay)
    }
}

// MARK: - Errors

enum RetryError: LocalizedError {
    case invalidResponse
    case maxRetriesExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        }
    }
}
