import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // App Icon & Name
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("CodeCheck")
                        .font(.system(size: 36, weight: .bold))

                    Text("Professional Construction Compliance")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Version 1.0.0 (Build 2025.12.04)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()

                // Mission Statement
                VStack(alignment: .leading, spacing: 16) {
                    Text("Our Mission")
                        .font(.headline)

                    Text("CodeCheck revolutionizes construction compliance by combining cutting-edge AR technology with AI-powered building code assistance. We help contractors, inspectors, and homeowners ensure their projects meet code requirements—accurately, efficiently, and confidently.")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Features
                VStack(alignment: .leading, spacing: 20) {
                    Text("Key Features")
                        .font(.headline)

                    FeatureHighlight(
                        icon: "arkit",
                        title: "ARKit Precision",
                        description: "LiDAR-powered measurements accurate to within millimeters"
                    )

                    FeatureHighlight(
                        icon: "cpu",
                        title: "AI Assistant",
                        description: "Instant answers powered by Claude AI"
                    )

                    FeatureHighlight(
                        icon: "checkmark.circle.fill",
                        title: "Real-time Compliance",
                        description: "Automatic code checking across 50+ jurisdictions"
                    )

                    FeatureHighlight(
                        icon: "chart.bar.fill",
                        title: "Project Management",
                        description: "Organize and track all your compliance work"
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Technology
                VStack(alignment: .leading, spacing: 12) {
                    Text("Built With")
                        .font(.headline)

                    Text("• SwiftUI & ARKit for iOS\n• FastAPI backend with PostgreSQL\n• Claude AI for intelligent assistance\n• PostGIS for jurisdiction mapping")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Credits
                VStack(alignment: .leading, spacing: 12) {
                    Text("Credits")
                        .font(.headline)

                    Text("Developed with ❤️ by the CodeCheck Team\n\nSpecial thanks to:\n• Anthropic for Claude AI\n• Apple for ARKit & LiDAR\n• The open-source community")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Copyright
                Text("© 2025 CodeCheck. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            .padding()
        }
        .navigationTitle("About")
    }
}

struct FeatureHighlight: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
