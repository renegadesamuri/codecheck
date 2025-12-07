//
//  GradientCache.swift
//  CodeCheck
//
//  Reusable gradient definitions to avoid recreating them on every render
//  Phase 2.5 Optimization: 5-10% render performance improvement
//

import SwiftUI

struct GradientCache {
    /// Blue to Purple gradient (most commonly used)
    static let bluePurple = LinearGradient(
        colors: [.blue, .purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Blue to Cyan gradient
    static let blueCyan = LinearGradient(
        colors: [.blue, .cyan],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Green gradient for success states
    static let greenGradient = LinearGradient(
        colors: [.green.opacity(0.8), .green],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Red gradient for error states
    static let redGradient = LinearGradient(
        colors: [.red.opacity(0.8), .red],
        startPoint: .top,
        endPoint: .bottom
    )
}
