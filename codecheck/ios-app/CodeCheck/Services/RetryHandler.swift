//
//  RetryHandler.swift
//  CodeCheck
//
//  Phase 3 Optimization: Retry Logic with Exponential Backoff
//  Automatically retries transient network failures
//

import Foundation

/// Handles automatic retry logic with exponential backoff for network requests
struct RetryHandler {

    /// Configuration for retry behavior
    struct Configuration {
        /// Maximum number of retry attempts (not including initial attempt)
        let maxRetries: Int

        /// Base delay between retries (doubles with each attempt)
        let baseDelay: TimeInterval

        /// Maximum delay cap (prevents excessive wait times)
        let maxDelay: TimeInterval

        /// Jitter factor (0-1) to randomize delay slightly
        let jitterFactor: Double

        /// Default configuration
        static let `default` = Configuration(
            maxRetries: 3,
            baseDelay: 1.0,
            maxDelay: 30.0,
            jitterFactor: 0.1
        )

        /// Aggressive retry for critical requests
        static let aggressive = Configuration(
            maxRetries: 5,
            baseDelay: 0.5,
            maxDelay: 16.0,
            jitterFactor: 0.2
        )

        /// Conservative retry for non-critical requests
        static let conservative = Configuration(
            maxRetries: 2,
            baseDelay: 2.0,
            maxDelay: 10.0,
            jitterFactor: 0.1
        )
    }

    /// Errors that indicate retry should be attempted
    enum RetryableError {
        case timeout
        case serverError(Int)
        case networkUnavailable
        case connectionLost
        case rateLimited(retryAfter: TimeInterval?)

        /// Check if an error is retryable
        static func isRetryable(_ error: Error) -> RetryableError? {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    return .timeout
                case .networkConnectionLost:
                    return .connectionLost
                case .notConnectedToInternet, .dataNotAllowed:
                    return .networkUnavailable
                case .cannotConnectToHost, .cannotFindHost:
                    return .networkUnavailable
                default:
                    return nil
                }
            }

            // Check for HTTP status codes in custom error types
            if let apiError = error as? APIError {
                switch apiError {
                case .timeout:
                    return .timeout
                case .networkError:
                    return .networkUnavailable
                default:
                    return nil
                }
            }

            return nil
        }

        /// Check if an HTTP status code is retryable
        static func isRetryableStatusCode(_ statusCode: Int) -> RetryableError? {
            switch statusCode {
            case 429:
                return .rateLimited(retryAfter: nil)
            case 500...599:
                return .serverError(statusCode)
            case 408:
                return .timeout
            default:
                return nil
            }
        }
    }

    /// Execute an async operation with retry logic
    /// - Parameters:
    ///   - config: Retry configuration
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    static func execute<T>(
        with config: Configuration = .default,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var attempt = 0

        while attempt <= config.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Check if we should retry
                guard let retryableError = RetryableError.isRetryable(error),
                      attempt < config.maxRetries else {
                    throw error
                }

                // Calculate delay with exponential backoff
                let delay = calculateDelay(
                    attempt: attempt,
                    config: config,
                    retryableError: retryableError
                )

                attempt += 1

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    /// Execute a network request with retry logic
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - session: The URLSession to use
    ///   - config: Retry configuration
    /// - Returns: Tuple of (Data, HTTPURLResponse)
    static func executeRequest(
        _ request: URLRequest,
        using session: URLSession = NetworkManager.shared.session,
        config: Configuration = .default
    ) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?
        var attempt = 0

        while attempt <= config.maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                // Check if status code indicates we should retry
                if let retryableError = RetryableError.isRetryableStatusCode(httpResponse.statusCode),
                   attempt < config.maxRetries {

                    let delay = calculateDelay(
                        attempt: attempt,
                        config: config,
                        retryableError: retryableError,
                        response: httpResponse
                    )

                    attempt += 1
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                return (data, httpResponse)

            } catch {
                lastError = error

                guard let retryableError = RetryableError.isRetryable(error),
                      attempt < config.maxRetries else {
                    throw error
                }

                let delay = calculateDelay(
                    attempt: attempt,
                    config: config,
                    retryableError: retryableError
                )

                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    /// Calculate delay for a retry attempt
    private static func calculateDelay(
        attempt: Int,
        config: Configuration,
        retryableError: RetryableError,
        response: HTTPURLResponse? = nil
    ) -> TimeInterval {
        // Check for Retry-After header (rate limiting)
        if case .rateLimited = retryableError,
           let retryAfterString = response?.value(forHTTPHeaderField: "Retry-After"),
           let retryAfter = TimeInterval(retryAfterString) {
            return min(retryAfter, config.maxDelay)
        }

        // Exponential backoff: baseDelay * 2^attempt
        var delay = config.baseDelay * pow(2.0, Double(attempt))

        // Apply max delay cap
        delay = min(delay, config.maxDelay)

        // Add jitter to prevent thundering herd
        let jitter = delay * config.jitterFactor * Double.random(in: -1...1)
        delay += jitter

        // Ensure delay is positive
        return max(delay, 0.1)
    }
}

// MARK: - Convenience Extensions

extension URLRequest {
    /// Execute this request with automatic retry
    func executeWithRetry(
        using session: URLSession = NetworkManager.shared.session,
        config: RetryHandler.Configuration = .default
    ) async throws -> (Data, HTTPURLResponse) {
        try await RetryHandler.executeRequest(self, using: session, config: config)
    }
}

// MARK: - Combined Deduplication + Retry

extension URLRequest {
    /// Execute with both deduplication and retry logic
    /// First deduplicates concurrent identical requests, then applies retry on failure
    func executeWithDeduplicationAndRetry(
        using session: URLSession = NetworkManager.shared.session,
        retryConfig: RetryHandler.Configuration = .default
    ) async throws -> Data {
        try await RetryHandler.execute(with: retryConfig) {
            try await RequestDeduplicator.shared.execute(request: self, using: session)
        }
    }
}
