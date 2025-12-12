# CodeCheck Authentication Architecture

## System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                         iOS App Layer                             │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    SwiftUI Views                            │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │  │
│  │  │ LoginView│  │RegisterV.│  │ ProfileV.│  │ HomeView │   │  │
│  │  └─────┬────┘  └─────┬────┘  └─────┬────┘  └─────┬────┘   │  │
│  │        │              │              │              │        │  │
│  │        └──────────────┴──────────────┴──────────────┘        │  │
│  │                          │                                   │  │
│  │                 @EnvironmentObject                           │  │
│  │                          ↓                                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    AuthService                               │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │ @Published Properties:                                  │  │  │
│  │  │  • isAuthenticated: Bool                                │  │  │
│  │  │  • currentUser: User?                                   │  │  │
│  │  │  • isLoading: Bool                                      │  │  │
│  │  │  • errorMessage: String?                                │  │  │
│  │  └────────────────────────────────────────────────────────┘  │  │
│  │                                                               │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │ Authentication Methods:                                 │  │  │
│  │  │  • register(email, password, name)                      │  │  │
│  │  │  • login(email, password)                               │  │  │
│  │  │  • loginWithBiometrics()                                │  │  │
│  │  │  • logout()                                             │  │  │
│  │  │  • fetchCurrentUser()                                   │  │  │
│  │  └────────────────────────────────────────────────────────┘  │  │
│  │                                                               │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │ Token Management:                                       │  │  │
│  │  │  • getValidAccessToken()                                │  │  │
│  │  │  • refreshAccessToken()                                 │  │  │
│  │  │  • scheduleTokenRefresh()                               │  │  │
│  │  │  • tokenExpirationDate: Date?                           │  │  │
│  │  └────────────────────────────────────────────────────────┘  │  │
│  │                                                               │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │ Authenticated Requests:                                 │  │  │
│  │  │  • makeAuthenticatedRequest(endpoint, method, body)     │  │  │
│  │  │  • Auto token injection                                 │  │  │
│  │  │  • Auto retry on 401                                    │  │  │
│  │  └────────────────────────────────────────────────────────┘  │  │
│  └───────────────────┬──────────────────┬───────────────────────┘  │
│                      │                  │                          │
│                      ↓                  ↓                          │
│  ┌─────────────────────────┐   ┌─────────────────────────┐        │
│  │   KeychainWrapper       │   │  LAContext (Biometrics)  │        │
│  │  ┌──────────────────┐   │   │  ┌──────────────────┐   │        │
│  │  │ • Access Token   │   │   │  │ • Face ID        │   │        │
│  │  │ • Refresh Token  │   │   │  │ • Touch ID       │   │        │
│  │  │ • Expiration     │   │   │  │ • Evaluation     │   │        │
│  │  └──────────────────┘   │   │  └──────────────────┘   │        │
│  └─────────────────────────┘   └─────────────────────────┘        │
└──────────────────────────────────────────────────────────────────┘
                               │
                               │ HTTPS
                               ↓
┌──────────────────────────────────────────────────────────────────┐
│                      Backend API Server                           │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                Authentication Endpoints                     │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │ POST /auth/register                                   │  │  │
│  │  │  • Request: email, password, name                     │  │  │
│  │  │  • Response: access_token, refresh_token, user        │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │ POST /auth/login                                      │  │  │
│  │  │  • Request: email, password                           │  │  │
│  │  │  • Response: access_token, refresh_token, user        │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │ POST /auth/refresh                                    │  │  │
│  │  │  • Request: refresh_token                             │  │  │
│  │  │  • Response: new access_token, refresh_token          │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │ GET /auth/me                                          │  │  │
│  │  │  • Headers: Authorization: Bearer <token>             │  │  │
│  │  │  • Response: user data                                │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    Protected Endpoints                      │  │
│  │  • All require Bearer token in Authorization header        │  │
│  │  • Return 401 for invalid/expired tokens                   │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

## Authentication Flow Diagrams

### 1. User Registration Flow

```
User                SwiftUI           AuthService         Keychain         Backend
 │                    │                   │                  │                │
 │  Enter Email/Pwd   │                   │                  │                │
 │───────────────────>│                   │                  │                │
 │                    │  register()       │                  │                │
 │                    │──────────────────>│                  │                │
 │                    │                   │  POST /auth/register             │
 │                    │                   │─────────────────────────────────>│
 │                    │                   │                  │    200 OK     │
 │                    │                   │<─────────────────────────────────│
 │                    │                   │                  │   (tokens)    │
 │                    │                   │  Save tokens     │                │
 │                    │                   │─────────────────>│                │
 │                    │                   │       OK         │                │
 │                    │                   │<─────────────────│                │
 │                    │  isAuthenticated  │                  │                │
 │                    │  = true           │                  │                │
 │  Show Main App     │<──────────────────│                  │                │
 │<───────────────────│                   │                  │                │
```

### 2. User Login Flow

```
User                SwiftUI           AuthService         Keychain         Backend
 │                    │                   │                  │                │
 │  Enter Credentials │                   │                  │                │
 │───────────────────>│                   │                  │                │
 │                    │  login()          │                  │                │
 │                    │──────────────────>│                  │                │
 │                    │                   │  POST /auth/login                │
 │                    │                   │─────────────────────────────────>│
 │                    │                   │                  │    200 OK     │
 │                    │                   │<─────────────────────────────────│
 │                    │                   │                  │   (tokens)    │
 │                    │                   │  Save tokens     │                │
 │                    │                   │─────────────────>│                │
 │                    │                   │  Schedule refresh│                │
 │                    │                   │  (5 min before)  │                │
 │                    │  isAuthenticated  │                  │                │
 │                    │  = true           │                  │                │
 │  Show Main App     │<──────────────────│                  │                │
 │<───────────────────│                   │                  │                │
```

### 3. Biometric Login Flow

```
User                SwiftUI           AuthService         LAContext    Keychain    Backend
 │                    │                   │                   │           │           │
 │  Tap Face ID       │                   │                   │           │           │
 │───────────────────>│                   │                   │           │           │
 │                    │ loginWithBio()    │                   │           │           │
 │                    │──────────────────>│                   │           │           │
 │                    │                   │  evaluatePolicy() │           │           │
 │                    │                   │──────────────────>│           │           │
 │  Face ID Prompt    │                   │                   │           │           │
 │<───────────────────────────────────────────────────────────│           │           │
 │                    │                   │      Success      │           │           │
 │                    │                   │<──────────────────│           │           │
 │                    │                   │  Get refresh token│           │           │
 │                    │                   │───────────────────────────────>│           │
 │                    │                   │                   │  token    │           │
 │                    │                   │<───────────────────────────────│           │
 │                    │                   │  POST /auth/refresh                       │
 │                    │                   │───────────────────────────────────────────>│
 │                    │                   │                   │           │  New tokens│
 │                    │                   │<───────────────────────────────────────────│
 │                    │                   │  Save new tokens  │           │           │
 │                    │                   │───────────────────────────────>│           │
 │                    │  isAuthenticated  │                   │           │           │
 │                    │  = true           │                   │           │           │
 │  Show Main App     │<──────────────────│                   │           │           │
 │<───────────────────│                   │                   │           │           │
```

### 4. Authenticated API Request Flow

```
View              AuthService         Keychain         Backend
 │                    │                  │                │
 │  API Request       │                  │                │
 │───────────────────>│                  │                │
 │                    │  Get token       │                │
 │                    │─────────────────>│                │
 │                    │      token       │                │
 │                    │<─────────────────│                │
 │                    │  Check expiration│                │
 │                    │  (5 min buffer)  │                │
 │                    │                  │                │
 │                    │  If expired:     │                │
 │                    │  POST /auth/refresh               │
 │                    │──────────────────────────────────>│
 │                    │                  │   New tokens   │
 │                    │<──────────────────────────────────│
 │                    │  Save tokens     │                │
 │                    │─────────────────>│                │
 │                    │                  │                │
 │                    │  GET /api/endpoint                │
 │                    │  Authorization: Bearer <token>    │
 │                    │──────────────────────────────────>│
 │                    │                  │    200 OK      │
 │                    │<──────────────────────────────────│
 │      Data          │                  │   (response)   │
 │<───────────────────│                  │                │
```

### 5. Token Refresh Flow (Automatic)

```
AuthService         Timer Task         Backend          Keychain
 │                      │                   │               │
 │  scheduleRefresh()   │                   │               │
 │─────────────────────>│                   │               │
 │                      │  Wait until       │               │
 │                      │  5 min before     │               │
 │                      │  expiration       │               │
 │                      │  ...              │               │
 │                      │  Time reached!    │               │
 │  refreshToken()      │                   │               │
 │<─────────────────────│                   │               │
 │                      │                   │               │
 │  Get refresh token   │                   │               │
 │──────────────────────────────────────────────────────────>│
 │                      │                   │     token     │
 │<──────────────────────────────────────────────────────────│
 │                      │                   │               │
 │  POST /auth/refresh  │                   │               │
 │──────────────────────────────────────────>│               │
 │                      │                   │  New tokens   │
 │<──────────────────────────────────────────│               │
 │                      │                   │               │
 │  Save new tokens     │                   │               │
 │──────────────────────────────────────────────────────────>│
 │                      │                   │               │
 │  Schedule next refresh                   │               │
 │─────────────────────>│                   │               │
```

### 6. Logout Flow

```
User                SwiftUI           AuthService         Keychain
 │                    │                   │                  │
 │  Tap Logout        │                   │                  │
 │───────────────────>│                   │                  │
 │                    │  logout()         │                  │
 │                    │──────────────────>│                  │
 │                    │                   │  Cancel refresh  │
 │                    │                   │  timer task      │
 │                    │                   │                  │
 │                    │                   │  Delete tokens   │
 │                    │                   │─────────────────>│
 │                    │                   │                  │
 │                    │  isAuthenticated  │                  │
 │                    │  = false          │                  │
 │                    │  currentUser = nil│                  │
 │  Show Login        │<──────────────────│                  │
 │<───────────────────│                   │                  │
```

## Security Architecture

### Token Storage Security

```
┌──────────────────────────────────────────────┐
│         iOS Security Stack                   │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │      Application Sandbox              │  │
│  │  ┌──────────────────────────────────┐  │  │
│  │  │   AuthService                    │  │  │
│  │  │   (Cannot access tokens directly)│  │  │
│  │  └──────────────┬───────────────────┘  │  │
│  │                 │ API Call             │  │
│  │                 ↓                      │  │
│  │  ┌──────────────────────────────────┐  │  │
│  │  │   KeychainWrapper                │  │  │
│  │  │   (Secure API interface)         │  │  │
│  │  └──────────────┬───────────────────┘  │  │
│  └─────────────────┼──────────────────────┘  │
│                    │ SecItem API              │
│                    ↓                          │
│  ┌──────────────────────────────────────────┐ │
│  │        iOS Keychain                      │ │
│  │  • Hardware-encrypted storage            │ │
│  │  • Biometric protection available        │ │
│  │  • App-specific access                   │ │
│  │  • Survives app deletion (configurable)  │ │
│  └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
                     │
                     ↓
        [Secure Element / Secure Enclave]
```

### Request Security Flow

```
┌─────────────────────────────────────────────────────┐
│                  API Request                        │
│                                                     │
│  1. AuthService.makeAuthenticatedRequest()         │
│     ↓                                               │
│  2. getValidAccessToken()                           │
│     • Check Keychain for token                      │
│     • Check expiration (5 min buffer)               │
│     • Auto-refresh if needed                        │
│     ↓                                               │
│  3. Create URLRequest                               │
│     • Set Authorization: Bearer <token>             │
│     • Set Content-Type: application/json            │
│     ↓                                               │
│  4. URLSession.data(for: request)                   │
│     • HTTPS encryption in transit                   │
│     • Certificate validation                        │
│     ↓                                               │
│  5. Handle Response                                 │
│     • 200-299: Success, return data                 │
│     • 401: Auto-refresh token and retry once        │
│     • Other: Throw appropriate error                │
│     ↓                                               │
│  6. Return decrypted data to caller                 │
└─────────────────────────────────────────────────────┘
```

## Data Flow

### User Data Flow

```
Backend          Network          AuthService       SwiftUI Views
   │                │                  │                  │
   │   User Data    │                  │                  │
   │───────────────>│                  │                  │
   │                │  AuthResponse    │                  │
   │                │─────────────────>│                  │
   │                │                  │  Parse & Store   │
   │                │                  │  currentUser     │
   │                │                  │  @Published      │
   │                │                  │──────────────────>│
   │                │                  │                  │  Display
   │                │                  │                  │  User Info
```

### State Management

```
┌──────────────────────────────────────────────────────────┐
│                    AuthService                           │
│  @MainActor class AuthService: ObservableObject         │
│                                                          │
│  @Published var isAuthenticated: Bool = false           │
│       │                                                  │
│       └──> Automatically updates all views              │
│                                                          │
│  @Published var currentUser: User? = nil                │
│       │                                                  │
│       └──> SwiftUI re-renders when changed              │
│                                                          │
│  @Published var isLoading: Bool = false                 │
│       │                                                  │
│       └──> Shows/hides loading indicators               │
│                                                          │
│  @Published var errorMessage: String? = nil             │
│       │                                                  │
│       └──> Displays error alerts                        │
└──────────────────────────────────────────────────────────┘
                         │
                         │ @EnvironmentObject
                         ↓
┌──────────────────────────────────────────────────────────┐
│                   All SwiftUI Views                      │
│  • LoginView                                             │
│  • RegisterView                                          │
│  • ProfileView                                           │
│  • All other views automatically update                  │
└──────────────────────────────────────────────────────────┘
```

## Component Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                      External Frameworks                     │
│                                                             │
│  • Foundation (URLSession, JSONEncoder/Decoder)             │
│  • LocalAuthentication (LAContext for Face ID/Touch ID)     │
│  • Security (Keychain Services)                             │
│  • Combine (@Published, ObservableObject)                   │
│  • SwiftUI (@StateObject, @EnvironmentObject)               │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      Core Services                          │
│                                                             │
│  ┌──────────────────┐    ┌──────────────────┐             │
│  │  AuthService     │    │ KeychainWrapper  │             │
│  │  (609 lines)     │───>│ (Secure Storage) │             │
│  └──────────────────┘    └──────────────────┘             │
│           │                                                 │
│           │ Uses                                            │
│           ↓                                                 │
│  ┌──────────────────┐                                      │
│  │  Models          │                                      │
│  │  • User          │                                      │
│  │  • AuthResponse  │                                      │
│  │  • Requests      │                                      │
│  └──────────────────┘                                      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                       │
│                                                             │
│  ┌──────────────────┐    ┌──────────────────┐             │
│  │  Views           │    │  ViewModels      │             │
│  │  • LoginView     │    │  (Optional)      │             │
│  │  • RegisterView  │    │                  │             │
│  │  • ProfileView   │    │                  │             │
│  └──────────────────┘    └──────────────────┘             │
└─────────────────────────────────────────────────────────────┘
```

## Error Handling Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Error Propagation Flow                     │
│                                                         │
│  Backend Error (HTTP 4xx/5xx)                           │
│         ↓                                               │
│  AuthService receives response                          │
│         ↓                                               │
│  Parse error body                                       │
│         ↓                                               │
│  Create AuthenticationError                             │
│         ↓                                               │
│  Set errorMessage @Published property                   │
│         ↓                                               │
│  SwiftUI View observes change                           │
│         ↓                                               │
│  Display user-friendly error message                    │
└─────────────────────────────────────────────────────────┘

Error Types Hierarchy:
┌───────────────────────────┐
│  AuthenticationError      │
│  ├─ invalidURL            │
│  ├─ invalidResponse       │
│  ├─ invalidCredentials    │
│  ├─ userAlreadyExists     │
│  ├─ badRequest            │
│  ├─ networkError          │
│  ├─ serverError           │
│  ├─ notAuthenticated      │
│  ├─ refreshTokenMissing   │
│  ├─ refreshTokenInvalid   │
│  ├─ biometricsNotAvailable│
│  ├─ biometricsFailed      │
│  ├─ noBiometricCredentials│
│  └─ unknownError          │
└───────────────────────────┘
```

## Performance Optimization

### Token Caching Strategy

```
┌─────────────────────────────────────────────────────┐
│             Token Access Pattern                    │
│                                                     │
│  Request 1: Get token from Keychain (slow)         │
│     ↓                                               │
│  Cache in memory (tokenExpirationDate)             │
│     ↓                                               │
│  Requests 2-N: Use cached expiration                │
│  • No Keychain access needed                        │
│  • Only check Date comparison (fast)                │
│     ↓                                               │
│  If expired: Refresh token                          │
│  • Update Keychain                                  │
│  • Update cache                                     │
└─────────────────────────────────────────────────────┘

Performance Metrics:
• Keychain access: ~10ms
• Date comparison: <1ms
• Token refresh: ~200ms (network)
• Biometric evaluation: ~500ms (user interaction)
```

### Async/Await Concurrency

```
┌─────────────────────────────────────────────────────┐
│          Concurrency Model                          │
│                                                     │
│  @MainActor AuthService                             │
│  • All UI updates on main thread                    │
│  • Prevents race conditions                         │
│  • Thread-safe by design                            │
│                                                     │
│  async methods:                                     │
│  • login()     ─┐                                   │
│  • register()  ─┤─> Can run concurrently           │
│  • logout()    ─┤   (but typically sequential)     │
│  • refresh()   ─┘                                   │
│                                                     │
│  Token refresh task:                                │
│  • Runs in background                               │
│  • Cancellable                                      │
│  • Non-blocking                                     │
└─────────────────────────────────────────────────────┘
```

## Summary

This architecture provides:
- **Security**: Keychain storage, HTTPS, biometric authentication
- **Reliability**: Auto token refresh, retry logic, error handling
- **Performance**: Token caching, async operations, optimized flows
- **Maintainability**: Clear separation of concerns, well-documented
- **Scalability**: Ready for additional features (2FA, social login, etc.)

---

**Version**: 1.0.0
**Last Updated**: 2025-01-19
