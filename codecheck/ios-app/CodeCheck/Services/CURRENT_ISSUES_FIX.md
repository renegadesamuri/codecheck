# CodeCheck - Current Issues Fix Guide

## Issues Summary
1. ✅ Sign-in problems - **PARTIALLY FIXED**
2. ✅ Network timeout problems - **FIXED**
3. ✅ AI assistant not working - **FIXED**

---

## 1. Network Timeout Fix ✅

### What Was Changed
Updated `NetworkManager.swift` to reduce timeout intervals:
- Request timeout: 60s → **15s**
- Resource timeout: 120s → **30s**

This will make connection failures appear faster, helping you identify issues quicker.

---

## 2. AI Assistant Authentication Fix ✅

### Problem
The `ConversationManager` was creating a `CodeLookupService` without passing the `AuthService`, causing 401 Unauthorized errors when trying to fetch building codes.

### What Was Changed
Updated `ConversationManager.swift` to:
- Accept an `AuthService` parameter in the initializer
- Pass it to the `CodeLookupService`

### What You Need To Do
**You must update your app initialization code** to pass the AuthService to ConversationManager.

Find your main app file (usually `CodeCheckApp.swift` or similar) and update it:

**BEFORE:**
```swift
@StateObject private var conversationManager = ConversationManager()
```

**AFTER:**
```swift
@StateObject private var authService = AuthService()
@StateObject private var conversationManager: ConversationManager

init() {
    let auth = AuthService()
    _authService = StateObject(wrappedValue: auth)
    _conversationManager = StateObject(wrappedValue: ConversationManager(authService: auth))
}
```

**OR** if you're already instantiating services:
```swift
// In your app's body, after creating authService
@StateObject private var authService = AuthService()
// Create conversation manager with auth reference
@StateObject private var conversationManager: ConversationManager

init() {
    let auth = AuthService()
    _authService = StateObject(wrappedValue: auth)
    _conversationManager = StateObject(wrappedValue: ConversationManager(authService: auth))
}
```

**COMPLETE EXAMPLE:**
```swift
import SwiftUI

@main
struct CodeCheckApp: App {
    @StateObject private var authService: AuthService
    @StateObject private var conversationManager: ConversationManager
    
    init() {
        // Create auth service first
        let auth = AuthService()
        _authService = StateObject(wrappedValue: auth)
        
        // Pass auth service to conversation manager
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

## 3. Sign-In Issues - Checklist

### A. Verify Backend is Running
```bash
# In your backend directory
# Make sure you see: "Server running on http://0.0.0.0:8000"
```

### B. Find Your Mac's IP Address

**Option 1 - Terminal:**
```bash
ipconfig getifaddr en0
# Example output: 192.168.1.100
```

**Option 2 - System Settings:**
1. System Settings → Network
2. Select WiFi
3. Find "IP Address"

### C. Update the IP Address in Code

You need to update **TWO FILES** with your Mac's actual IP address:

**File 1: `AuthService.swift`** (around line 296)
```swift
#else
// For physical device - IMPORTANT: Update this with your Mac's IP address
return "http://YOUR_MAC_IP_HERE:8000"  // UPDATE THIS
#endif
```

**File 2: `CodeLookupService.swift`** (around line 23)
```swift
#else
// For physical device - IMPORTANT: Update this with your Mac's IP address
self.baseURL = "http://YOUR_MAC_IP_HERE:8000"  // UPDATE THIS
#endif
```

**Replace `YOUR_MAC_IP_HERE` with your actual IP** (e.g., `192.168.1.100`)

### D. Verify Same Network
- ✅ Mac and iPhone on same WiFi
- ❌ Won't work with different networks
- ❌ Won't work with cellular data

### E. Test Connection

1. Open CodeCheck app
2. On login screen, tap "Server Settings" (if available)
3. Test connection to your backend

**OR test in Safari on iPhone:**
- Navigate to: `http://YOUR_MAC_IP:8000`
- You should see a response from your backend

---

## 4. Additional Debugging Steps

### Enable Logging
The app already has detailed logging. Check Xcode console for:

```
🔐 Attempting login to: http://...
✅ Login successful
❌ Auth error: ...
❌ Network error: ...
```

### Common Error Messages & Solutions

#### "Cannot connect to server"
- **Cause**: Backend not running or wrong IP
- **Fix**: Start backend, verify IP address

#### "Connection timed out"  
- **Cause**: Firewall, slow network, or wrong port
- **Fix**: 
  - Check Mac Firewall (System Settings → Network → Firewall)
  - Verify port 8000 is not blocked
  - Make sure backend is responding

#### "Authentication required. Please log in"
- **Cause**: Token expired or missing
- **Fix**: 
  - Log out and log back in
  - Make sure you're passing AuthService to services that need it

#### "Invalid response from server"
- **Cause**: Backend returning errors or wrong format
- **Fix**: Check backend logs for errors

### Test Backend Directly

```bash
# Test if port 8000 is listening
lsof -i :8000

# Should show Python process

# Test endpoint directly
curl http://localhost:8000

# Test from IP (as iPhone sees it)
curl http://YOUR_MAC_IP:8000

# Test login endpoint
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

---

## 5. AI Assistant Specific Checks

After making the ConversationManager changes:

### Verify AI Assistant Has Auth
The AI assistant needs authentication to fetch building codes. Make sure:

1. ✅ You're logged in (not in demo mode)
2. ✅ ConversationManager receives AuthService (see section 2)
3. ✅ Backend `/conversation` endpoint is working

### Test AI Assistant Endpoint
```bash
# First, get an auth token by logging in
# Then test the conversation endpoint:

curl -X POST http://localhost:8000/conversation \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "message": "What are stair requirements?",
    "project_type": "residential",
    "location": "California"
  }'
```

### Backend Requirements
Your backend needs:
- ✅ `/conversation` endpoint implemented
- ✅ OpenAI API or equivalent AI service configured
- ✅ Authentication middleware working

---

## 6. Quick Validation Checklist

Run through this checklist:

- [ ] Backend is running on port 8000
- [ ] Mac IP address is updated in both `AuthService.swift` and `CodeLookupService.swift`
- [ ] iPhone and Mac are on the same WiFi network
- [ ] Can access `http://MAC_IP:8000` in iPhone Safari
- [ ] Updated app initialization to pass AuthService to ConversationManager
- [ ] Cleaned and rebuilt the Xcode project
- [ ] Logged out and logged back in (if testing sign-in)
- [ ] Backend logs show incoming requests
- [ ] Xcode console shows detailed error messages

---

## 7. If Still Not Working

### Collect This Information:
1. Device type (Simulator or Physical iPhone model)
2. Mac's IP address
3. Backend server logs (last 20 lines)
4. Xcode console output (filter for "❌" or "error")
5. Screenshot of any error messages

### Try These:
1. **Restart everything**: Backend server, Xcode, iPhone
2. **Clear app data**: Delete app and reinstall
3. **Test with Simulator first**: Easier to debug with localhost
4. **Use demo mode**: Test if UI works without backend

### Nuclear Option:
```bash
# Clean Xcode build
# In Xcode: Product → Clean Build Folder (Cmd+Shift+K)

# Or use command line:
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Rebuild project
```

---

## 8. Production Deployment Notes

When ready to deploy to production:

1. Update backend URL in both services:
```swift
case .production:
    return "https://your-production-api.com"
```

2. Remove or secure demo mode

3. Add proper error handling for production

4. Enable HTTPS (not HTTP)

5. Update Info.plist to remove local networking exception:
```xml
<!-- Remove or comment out for production -->
<!-- <key>NSAllowsLocalNetworking</key>
<true/> -->
```

---

## Summary of Changes Made

### Files Modified:
1. ✅ `NetworkManager.swift` - Reduced timeouts
2. ✅ `ConversationManager.swift` - Added AuthService support

### Files You Need to Modify:
1. ⚠️ Your main app file (e.g., `CodeCheckApp.swift`) - Pass AuthService to ConversationManager
2. ⚠️ `AuthService.swift` - Update IP address for physical device
3. ⚠️ `CodeLookupService.swift` - Update IP address for physical device

---

## Getting Help

If you're still stuck after following this guide, provide:
1. The exact error message
2. Xcode console output
3. Backend server logs
4. Which step you're stuck on

Good luck! 🚀
