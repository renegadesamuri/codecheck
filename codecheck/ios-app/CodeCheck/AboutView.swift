import SwiftUI

struct AboutView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        List {
            // App Info Section
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("CodeCheck")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("AI-Powered Code Review")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)
            
            // Description Section
            Section {
                Text("CodeCheck is your intelligent code review assistant, helping you write better code through AI-powered analysis and real-time feedback.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Legal Section
            Section("Legal") {
                NavigationLink {
                    ScrollView {
                        Text(privacyPolicyText)
                            .padding()
                    }
                    .navigationTitle("Privacy Policy")
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                
                NavigationLink {
                    ScrollView {
                        Text(termsOfServiceText)
                            .padding()
                    }
                    .navigationTitle("Terms of Service")
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Terms of Service", systemImage: "doc.text")
                }
                
                NavigationLink {
                    LicensesView()
                } label: {
                    Label("Open Source Licenses", systemImage: "doc.plaintext")
                }
            }
            
            // Links Section
            Section("Links") {
                Link(destination: URL(string: "https://codecheck.com")!) {
                    Label("Website", systemImage: "globe")
                }
                
                Link(destination: URL(string: "https://github.com/codecheck")!) {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            
            // Copyright Section
            Section {
                Text("© 2024 CodeCheck. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var privacyPolicyText: String {
        """
        Privacy Policy
        
        Last updated: December 4, 2024
        
        CodeCheck is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our application.
        
        Information We Collect
        • Account information (email, name)
        • Code and project data you choose to analyze
        • Usage statistics and analytics
        
        How We Use Your Information
        • To provide and maintain our service
        • To improve and personalize your experience
        • To communicate with you about updates and support
        
        Data Security
        We implement appropriate security measures to protect your information. Your code is processed securely and is never shared with third parties without your consent.
        
        Contact Us
        If you have questions about this Privacy Policy, please contact us at privacy@codecheck.com.
        """
    }
    
    private var termsOfServiceText: String {
        """
        Terms of Service
        
        Last updated: December 4, 2024
        
        Welcome to CodeCheck. By using our service, you agree to these terms.
        
        Use of Service
        • You must be at least 13 years old to use CodeCheck
        • You are responsible for maintaining the security of your account
        • You retain all rights to your code and projects
        
        Acceptable Use
        • Do not use the service for any illegal purposes
        • Do not attempt to reverse engineer or compromise the service
        • Respect other users and community guidelines
        
        Service Availability
        We strive to provide reliable service but cannot guarantee 100% uptime. We reserve the right to modify or discontinue features with notice.
        
        Liability
        CodeCheck is provided "as is" without warranties. We are not liable for any damages arising from use of the service.
        
        Changes to Terms
        We may update these terms from time to time. Continued use of the service constitutes acceptance of updated terms.
        
        Contact
        For questions about these terms, contact legal@codecheck.com.
        """
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section {
                Text("CodeCheck uses the following open source software:")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Section("SwiftUI") {
                Text("Copyright © 2024 Apple Inc.")
                    .font(.caption)
                Text("All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Other Dependencies") {
                Text("Additional open source licenses and attributions will be listed here as dependencies are added to the project.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
