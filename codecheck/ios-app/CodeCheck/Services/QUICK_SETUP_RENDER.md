# Quick Setup - You Already Have Render! 🚀

Since you already have Render, here's the fast track to get your app working for everyone.

---

## 📋 Quick Checklist (5 minutes)

### ✅ Step 1: Get Your Render URL

1. Go to: https://dashboard.render.com
2. Click on your backend service (the one running your FastAPI code)
3. Find the URL at the top - looks like:
   ```
   https://codecheck-api-abc123.onrender.com
   ```
4. **Copy this URL** - you'll need it in the next step

---

### ✅ Step 2: Choose Your Update Method

Pick **ONE** of these three options:

#### **Option A: Use APIConfiguration.swift (Recommended)**

I already created this file for you. Just update line 79:

**File**: `APIConfiguration.swift`

```swift
private var productionURL: String {
    return "https://YOUR-ACTUAL-URL.onrender.com"  // Paste your Render URL here
}
```

Then update your `AuthService.swift` initialization:
```swift
init() {
    self.baseURL = APIConfiguration.shared.baseURL  // Use the config manager
    self.keychain = KeychainWrapper()
}
```

And `CodeLookupService.swift`:
```swift
init(authService: AuthService? = nil) {
    self.baseURL = APIConfiguration.shared.baseURL  // Use the config manager
    self.authService = authService
}
```

#### **Option B: Quick Update to Existing Code**

Update these two files directly:

**File 1**: `AuthService.swift` (around line 290)
```swift
case .production:
    return "https://YOUR-ACTUAL-URL.onrender.com"  // Your Render URL
```

**File 2**: `CodeLookupService.swift` (around line 15-25)
```swift
init(authService: AuthService? = nil) {
    let useCustomServer = UserDefaults.standard.bool(forKey: "useCustomServer")
    let customServerURL = UserDefaults.standard.string(forKey: "customServerURL")
    
    if useCustomServer, let customURL = customServerURL, !customURL.isEmpty {
        self.baseURL = customURL
    } else {
        #if DEBUG
        // Development - local testing
        #if targetEnvironment(simulator)
        self.baseURL = "http://localhost:8000"
        #else
        self.baseURL = "http://10.0.0.214:8000"
        #endif
        #else
        // Production - use Render
        self.baseURL = "https://YOUR-ACTUAL-URL.onrender.com"  // Your Render URL
        #endif
    }
    
    self.authService = authService
}
```

#### **Option C: Custom Server Settings (For Testing)**

Use the app's built-in server settings:
1. Open your app
2. Go to Login screen → "Server Settings"
3. Enable "Use Custom Server"
4. Enter your Render URL
5. Save

**Note**: This is stored locally per device - good for testing, not for production release.

---

### ✅ Step 3: Update ConversationManager

Make sure your main app file passes AuthService to ConversationManager:

**File**: Your main app file (e.g., `CodeCheckApp.swift`)

```swift
@main
struct CodeCheckApp: App {
    @StateObject private var authService: AuthService
    @StateObject private var conversationManager: ConversationManager
    
    init() {
        let auth = AuthService()
        _authService = StateObject(wrappedValue: auth)
        _conversationManager = StateObject(wrappedValue: ConversationManager(authService: auth))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(conversationManager)
        }
    }
}
```

---

### ✅ Step 4: Test Your Backend

Before updating the app, make sure your Render backend is working:

```bash
# Replace with your actual URL
curl https://YOUR-ACTUAL-URL.onrender.com/

# Test auth endpoint
curl -X POST https://YOUR-ACTUAL-URL.onrender.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

**Expected**: JSON response from your backend

**If it fails**:
- Check Render dashboard for errors
- Look at Logs in Render
- Make sure service is "Running" (not "Suspended")

---

### ✅ Step 5: Update iOS App & Test

1. **Clean Build**:
   ```
   Xcode → Product → Clean Build Folder (Cmd+Shift+K)
   ```

2. **Rebuild**:
   ```
   Xcode → Product → Build (Cmd+B)
   ```

3. **Test on Simulator**:
   - If using APIConfiguration: Set environment to `.production`
   - Or just test with Release build
   - Try logging in - should connect to Render

4. **Test on Physical Device**:
   - Deploy to your iPhone
   - Try logging in
   - Test AI assistant
   - Everything should work!

---

## 🎯 Which Build Configuration Uses Which URL?

### With APIConfiguration (Option A):

```swift
// In APIConfiguration.swift, the init() decides:
#if DEBUG
self.currentEnvironment = .development  // Uses localhost/local IP
#else
self.currentEnvironment = .production   // Uses Render URL
#endif
```

**Debug Build** (Cmd+R):
- Simulator: `http://localhost:8000`
- Device: `http://10.0.0.214:8000`

**Release Build** (Archive):
- Simulator: `https://your-url.onrender.com`
- Device: `https://your-url.onrender.com`

### To Force Production in Debug:

```swift
// In your app's init or AppDelegate
#if DEBUG
// Uncomment to test production in debug builds
// APIConfiguration.shared.setEnvironment(.production)
#endif
```

---

## 🐛 Troubleshooting

### "Connection timeout" / "Cannot connect"

**Check**:
1. Is your Render service running?
   - Dashboard → Your Service → Status should be "Running"
2. Did the service fall asleep?
   - Render free tier sleeps after 15 min
   - First request wakes it up (takes ~30s)
3. Is the URL correct?
   - No typos, includes `https://`
   - No trailing slash

**Fix**:
- Wait 30 seconds and retry (service waking up)
- Check Render logs for errors

### "401 Unauthorized" on AI Assistant

**This was the bug!** Make sure:
- ✅ ConversationManager receives AuthService
- ✅ CodeLookupService receives AuthService
- ✅ You updated your app initialization (Step 3)

### "SSL/Certificate error"

**Check**:
- Using `https://` not `http://`
- Render provides auto SSL - should just work

---

## ⚡ Render Free Tier Gotchas

### Sleep/Wake Behavior
- **Sleeps**: After 15 minutes of no requests
- **Wakes**: On first request (takes ~30 seconds)
- **Impact**: First user after idle period waits longer

**Solution 1**: Add wake-up handler in app
```swift
func wakeUpServerIfNeeded() async {
    // Ping server before critical operations
    guard baseURL.contains("onrender.com") else { return }
    
    do {
        let url = URL(string: baseURL)!
        _ = try await URLSession.shared.data(from: url)
        try await Task.sleep(nanoseconds: 2_000_000_000)  // Wait 2s
    } catch {
        // Server is waking up, that's okay
    }
}
```

**Solution 2**: Upgrade to paid tier ($7/month)
- Service stays running 24/7
- No wake-up delay

### Free Tier Limits
- ✅ 750 hours/month (plenty!)
- ✅ Free SSL
- ✅ Auto-deploy from Git
- ⚠️ Sleeps after 15 min
- ⚠️ May be slower than paid

---

## 🎉 You're Done!

After updating the URL:

**For Development (you)**:
- Debug builds still use `localhost` on Simulator
- Easy to test locally

**For Production (everyone)**:
- Release builds use Render
- Works for all users
- No IP address needed
- Works anywhere with internet

---

## 🚀 Next Steps

### Today:
- [x] Get Render URL
- [ ] Update production URL in code
- [ ] Update ConversationManager initialization
- [ ] Test with release build

### Before Sharing:
- [ ] Test AI assistant works
- [ ] Test login/signup
- [ ] Test on multiple devices
- [ ] Monitor Render logs

### Before App Store:
- [ ] Verify release build uses production
- [ ] Test thoroughly
- [ ] Set up error monitoring
- [ ] Consider upgrading Render plan

---

## 📊 Monitor Your Render Service

**View Logs**:
1. Dashboard → Your Service
2. Click "Logs" tab
3. See real-time requests

**Check Metrics**:
- CPU usage
- Memory usage
- Request count
- Response times

**Get Alerts**:
- Settings → Notifications
- Get notified if service goes down

---

## 💡 Pro Tips

### Environment Switching
```swift
// Temporarily test production in development:
APIConfiguration.shared.setEnvironment(.production)

// Back to development:
APIConfiguration.shared.setEnvironment(.development)
```

### Add to Settings View
```swift
Section("Developer") {
    Picker("Environment", selection: $selectedEnvironment) {
        Text("Development").tag(APIConfiguration.Environment.development)
        Text("Production").tag(APIConfiguration.Environment.production)
    }
    
    Text(APIConfiguration.shared.baseURL)
        .font(.caption)
        .foregroundColor(.secondary)
}
```

---

## ✅ Summary

**What you need to do**:
1. Get your Render URL from dashboard
2. Update ONE file (`APIConfiguration.swift` OR `AuthService.swift` + `CodeLookupService.swift`)
3. Update app initialization to pass AuthService
4. Test!

**Result**:
- ✅ App works for everyone
- ✅ No IP address needed
- ✅ Works anywhere
- ✅ Ready to share!

---

Need help with any step? Let me know your Render URL and I can help you update the exact files!
