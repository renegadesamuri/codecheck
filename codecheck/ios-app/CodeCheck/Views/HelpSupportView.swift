import SwiftUI

struct HelpSupportView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section("Getting Started") {
                HelpRow(
                    icon: "ruler",
                    title: "Taking Measurements",
                    description: "Learn how to use ARKit to measure stairs, doors, and railings"
                )

                HelpRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "AI Assistant",
                    description: "Get instant answers about building codes and compliance"
                )

                HelpRow(
                    icon: "folder.fill",
                    title: "Managing Projects",
                    description: "Organize your measurements by project and location"
                )
            }

            Section("Common Questions") {
                DisclosureGroup {
                    Text("CodeCheck requires iPhone 12 Pro or later with LiDAR sensor. Older devices can still use AI Assistant and project management features.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } label: {
                    Text("What devices are supported?")
                }

                DisclosureGroup {
                    Text("Your measurements are stored locally on your device and synced with your account. We use end-to-end encryption for all data transmission.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } label: {
                    Text("Is my data secure?")
                }

                DisclosureGroup {
                    Text("Yes! CodeCheck works offline for measurements and project management. AI features require internet connection.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } label: {
                    Text("Can I use CodeCheck offline?")
                }

                DisclosureGroup {
                    Text("CodeCheck covers the International Building Code (IBC), International Residential Code (IRC), and automatically detects local jurisdictions based on your location.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } label: {
                    Text("What building codes are covered?")
                }
            }

            Section("Contact Support") {
                Button {
                    if let url = URL(string: "mailto:support@getcodecheck.com") {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Label("Email Support", systemImage: "envelope")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    if let url = URL(string: "https://docs.getcodecheck.com") {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Label("Documentation", systemImage: "book")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    if let url = URL(string: "https://github.com/yourusername/codecheck/issues") {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Label("Report an Issue", systemImage: "exclamationmark.triangle")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(GradientCache.bluePurple)

                        Text("Need more help?")
                            .font(.headline)

                        Text("Our support team is here to help")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                }
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Help & Support")
    }
}

struct HelpRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(GradientCache.bluePurple)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
}
