# AuthService Implementation Checklist

Use this checklist to ensure proper integration of the AuthService into your CodeCheck app.

## 1. Files Created/Updated

- [x] `/CodeCheck/Services/AuthService.swift` - Complete authentication service
- [x] `/CodeCheck/Models/Models.swift` - Added User and Auth models
- [x] `AUTH_SERVICE_DOCUMENTATION.md` - Comprehensive documentation
- [x] `INTEGRATION_EXAMPLE.swift` - Integration examples

## 2. Xcode Project Configuration

### Required Capabilities
- [ ] Enable Keychain Sharing in Signing & Capabilities
  1. Open project in Xcode
  2. Select CodeCheck target
  3. Go to "Signing & Capabilities"
  4. Click "+ Capability"
  5. Add "Keychain Sharing"

### Info.plist Entries
- [ ] Add Face ID/Touch ID usage description
  ```xml
  <key>NSFaceIDUsageDescription</key>
  <string>CodeCheck uses Face ID to securely log you in</string>
  ```

### App Transport Security (Development Only)
- [ ] Allow localhost connections for development
  ```xml
  <key>NSAppTransportSecurity</key>
  <dict>
      <key>NSAllowsLocalNetworking</key>
      <true/>
      <key>NSAllowsArbitraryLoads</key>
      <false/>
  </dict>
  ```

## 3. Code Integration

### App Entry Point
- [ ] Initialize AuthService as @StateObject
- [ ] Pass as @EnvironmentObject to ContentView

```swift
@main
struct CodeCheckApp: App {
    @StateObject private var authService = AuthService(environment: .development)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
```

### Content View
- [ ] Add authentication state check
- [ ] Show login/register for unauthenticated users
- [ ] Show main app for authenticated users

```swift
struct ContentView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        if authService.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}
```

### Login/Register Views
- [ ] Create LoginView with email/password fields
- [ ] Add biometric login button (if available)
- [ ] Create RegisterView with name/email/password fields
- [ ] Display error messages from authService.errorMessage
- [ ] Show loading state with authService.isLoading

### Main App Views
- [ ] Add Profile tab with user info
- [ ] Add logout button
- [ ] Display authService.currentUser information

## 4. Service Integration

### Update Existing Services
- [ ] Update CodeLookupService to accept authService parameter
- [ ] Replace direct URLSession calls with authService.makeAuthenticatedRequest()
- [ ] Update other services that need authentication

Example:
```swift
class CodeLookupService {
    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func checkCompliance(...) async throws -> ComplianceResponse {
        let data = try await authService.makeAuthenticatedRequest(
            to: "/check",
            method: "POST",
            body: body
        )
        // ... decode response
    }
}
```

## 5. Backend Setup

### Authentication Endpoints
- [ ] Implement POST /auth/register
- [ ] Implement POST /auth/login
- [ ] Implement POST /auth/refresh
- [ ] Implement GET /auth/me

### Token Configuration
- [ ] Set appropriate token expiration times (recommended: 1 hour for access, 7 days for refresh)
- [ ] Implement JWT signing and verification
- [ ] Add refresh token rotation (optional but recommended)

### Protected Endpoints
- [ ] Add authentication middleware
- [ ] Verify Bearer tokens on protected routes
- [ ] Return 401 for invalid/expired tokens

## 6. Testing

### Manual Testing
- [ ] Test user registration flow
- [ ] Test login with valid credentials
- [ ] Test login with invalid credentials
- [ ] Test automatic token refresh
- [ ] Test logout
- [ ] Test app restart (persistence)
- [ ] Test biometric login (on physical device)
- [ ] Test authenticated API requests
- [ ] Test token expiration handling

### Edge Cases
- [ ] Test with no internet connection
- [ ] Test with slow network
- [ ] Test with backend server down
- [ ] Test token expiration during active session
- [ ] Test simultaneous requests
- [ ] Test logout during API request

### Device Testing
- [ ] Test on iOS Simulator
- [ ] Test on physical iPhone (Face ID)
- [ ] Test on physical iPhone (Touch ID)
- [ ] Test on physical iPad

## 7. Security Verification

- [ ] Verify tokens are stored in Keychain (not UserDefaults)
- [ ] Verify HTTPS is used for production
- [ ] Verify sensitive data is not logged
- [ ] Verify biometric authentication requires device passcode
- [ ] Verify tokens are cleared on logout
- [ ] Review error messages don't leak sensitive info

## 8. Production Preparation

### Configuration
- [ ] Update production URL in AuthService.Environment
- [ ] Remove NSAllowsArbitraryLoads from Info.plist
- [ ] Enable proper App Transport Security settings
- [ ] Consider adding certificate pinning

### Code Review
- [ ] Review all TODOs and FIXMEs
- [ ] Remove debug print statements
- [ ] Add analytics/logging (optional)
- [ ] Review error handling

### Documentation
- [ ] Document backend API requirements
- [ ] Document environment configuration
- [ ] Add inline code documentation
- [ ] Update README with auth information

## 9. Optional Enhancements

- [ ] Add "Remember Me" option
- [ ] Add password strength indicator
- [ ] Add email validation
- [ ] Add "Forgot Password" flow
- [ ] Add email verification flow
- [ ] Add 2FA support
- [ ] Add social login (Apple Sign In, Google)
- [ ] Add session timeout warning
- [ ] Add multiple device management

## 10. Deployment

- [ ] Test in TestFlight
- [ ] Verify analytics/crash reporting
- [ ] Monitor authentication success/failure rates
- [ ] Set up backend monitoring for auth endpoints
- [ ] Prepare rollback plan

## Common Issues & Solutions

### Issue: "Keychain item not found"
**Solution**: Ensure Keychain Sharing capability is enabled in Xcode

### Issue: Cannot connect to localhost on device
**Solution**:
1. Use Mac's IP address instead of localhost
2. Update baseURL: `http://192.168.1.XXX:8000`
3. Ensure device and Mac on same network

### Issue: Biometric authentication not working
**Solution**:
1. Add NSFaceIDUsageDescription to Info.plist
2. Test on physical device (not simulator)
3. Ensure Face ID/Touch ID enabled in Settings

### Issue: Token refresh fails silently
**Solution**:
1. Check backend refresh endpoint
2. Verify refresh token hasn't expired
3. Check error handling in scheduleTokenRefresh()

### Issue: User logged out unexpectedly
**Solution**:
1. Check token expiration times
2. Verify backend token validation
3. Check for network interruptions

## Resources

- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Local Authentication Framework](https://developer.apple.com/documentation/localauthentication)
- [URLSession Documentation](https://developer.apple.com/documentation/foundation/urlsession)
- [SwiftUI State Management](https://developer.apple.com/documentation/swiftui/state-and-data-flow)
- [JWT.io](https://jwt.io) - JWT debugging

## Support

For issues or questions:
1. Check AUTH_SERVICE_DOCUMENTATION.md
2. Review INTEGRATION_EXAMPLE.swift
3. Check backend API logs
4. Review Xcode console for errors

## Next Steps

After completing this checklist:
1. Run comprehensive testing
2. Fix any issues found
3. Optimize performance
4. Add analytics (optional)
5. Deploy to TestFlight
6. Gather user feedback
7. Iterate and improve

---

**Last Updated**: 2025-01-19
**Version**: 1.0.0
