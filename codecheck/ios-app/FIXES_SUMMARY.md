# CodeCheck iOS - What I Fixed

## Summary
Your app was timing out because it was trying to connect to two different ports (8000 and 8001) and had long timeout intervals. I've fixed these issues and added powerful debugging tools.

## Key Changes

### 1. ✅ Fixed Port Mismatch
**Problem**: 
- `AuthService` was using port 8000
- `CodeLookupService` was using port 8001
- Your backend likely runs on only one port

**Solution**:
- Both services now consistently use port **8000**

### 2. ✅ Reduced Timeout Intervals
**Problem**: 
- 60-second timeouts made debugging very slow
- Had to wait a full minute to see connection failures

**Solution**:
- Request timeout: 60s → **15s**
- Resource timeout: 60s → **30s**
- Much faster feedback when something's wrong

### 3. ✅ Added Developer Tools
**New Files Created**:

#### `DeveloperSettingsView.swift`
- Easy server URL configuration
- Quick presets for common scenarios
- Shows current active configuration
- Built-in help and setup guide

#### `ConnectionTestView.swift`
- One-tap connection testing
- Detailed error diagnostics
- Specific troubleshooting tips
- Shows current device and URL info

#### `NetworkDiagnosticsView.swift`
- Real-time network status monitoring
- WiFi vs Cellular detection
- System information display
- Step-by-step setup instructions

#### `CONNECTION_TROUBLESHOOTING.md`
- Comprehensive troubleshooting guide
- Common issues and solutions
- Network requirements
- Testing methods

## How to Use the New Tools

### From Login Screen:
1. Open the CodeCheck app
2. Tap **"Server Settings"** button (gear icon)
3. Choose from:
   - **Test Connection** - Quick connectivity test
   - **Network Diagnostics** - Real-time network status
   - **Quick Presets** - One-tap server configuration

### Quick Actions:
```
Simulator → Use "localhost" preset
Physical Device → Use "Physical Device" preset (update IP if needed)
Custom Server → Enable custom server and enter URL
```

## What You Need to Do Now

### Step 1: Find Your Mac's IP Address
**Terminal Method** (easiest):
```bash
ipconfig getifaddr en0
```
This will print something like: `192.168.1.100`

**System Settings Method**:
1. System Settings → Network
2. Select WiFi
3. Look for "IP Address"

### Step 2: Update the App Configuration

**Option A - Use Quick Preset**:
1. Open app
2. Tap "Server Settings"
3. Tap "Physical Device (10.0.0.214)" if that's your IP
4. Or tap "Local Network" and enter your IP

**Option B - Manual Configuration**:
1. Enable "Use Custom Server"
2. Enter: `http://YOUR_MAC_IP:8000`
3. Tap "Save Server URL"

### Step 3: Test Connection
1. Tap "Test Connection"
2. Wait for results
3. If successful: ✅ You're ready!
4. If failed: Read the detailed error message

### Step 4: Check Network Diagnostics
1. Tap "Network Diagnostics"
2. Verify:
   - ✅ Network connected
   - ✅ Connection type: WiFi
   - ✅ Low cost network (not cellular)

## Common Scenarios

### Scenario 1: Testing in iOS Simulator
```
No changes needed!
Default: http://localhost:8000
This automatically works in the Simulator
```

### Scenario 2: Testing on Physical iPhone
```
Required changes:
1. Find your Mac's IP (e.g., 192.168.1.100)
2. In app: Server Settings → Use Custom Server
3. Enter: http://192.168.1.100:8000
4. Both devices must be on same WiFi
```

### Scenario 3: Backend on Different Port
```
If your backend uses port 5000 instead:
1. Server Settings → Use Custom Server
2. Enter: http://YOUR_MAC_IP:5000
3. Update both AuthService and CodeLookupService code
```

## Troubleshooting Quick Reference

### "Cannot Connect to Host"
- ❌ Backend not running → Start your backend
- ❌ Wrong IP → Verify Mac's IP address
- ❌ Different networks → Connect to same WiFi

### "Connection Timed Out"
- ❌ Firewall blocking → Check Mac firewall settings
- ❌ Server slow → Restart backend
- ❌ Network issues → Try different WiFi

### "Cannot Find Host"
- ❌ Invalid URL → Use IP address format: `http://192.168.1.100:8000`
- ❌ Typo in URL → Double-check for spaces or errors

### "Still Not Working?"
1. Check Network Diagnostics → Must show WiFi
2. Run Connection Test → Read detailed error
3. Verify backend logs → Is it receiving requests?
4. Check Xcode console → Look for 🔌 and ❌ symbols

## Code Changes Summary

### AuthService.swift
```swift
// Line ~32: Reduced timeouts
configuration.timeoutIntervalForRequest = 15  // was 60
configuration.timeoutIntervalForResource = 30  // was 60
```

### CodeLookupService.swift
```swift
// Line ~9-24: Changed initialization to match AuthService
// Port changed from 8001 to 8000
#else
self.baseURL = "http://10.0.0.214:8000"  // was 8001
#endif

// Reduced timeouts
configuration.timeoutIntervalForRequest = 15  // was 30
configuration.timeoutIntervalForResource = 30  // was 60
```

### AuthView.swift
```swift
// Line ~159: Updated to use new DeveloperSettingsView
.sheet(isPresented: $showingDebugSettings) {
    DeveloperSettingsView()
        .environmentObject(authService)
        .presentationDetents([.large])
}
```

## Testing Your Fix

### Quick Test (30 seconds):
1. Open app on your iPhone
2. Tap "Server Settings"
3. Tap "Test Connection"
4. Should succeed within 15 seconds

### Full Test (2 minutes):
1. Test connection ✓
2. Check network diagnostics ✓
3. Try logging in ✓
4. Try a code lookup ✓

## Next Steps

1. **Update the hardcoded IP** if `10.0.0.214` isn't your Mac's IP:
   - In `AuthService.swift` line ~45
   - Or use the app's Server Settings instead

2. **Test on both Simulator and Device**:
   - Simulator should work automatically
   - Device needs IP configuration

3. **Check your backend**:
   - Make sure it's running on port 8000
   - Verify it responds to `http://YOUR_MAC_IP:8000`

4. **If still having issues**:
   - Read `CONNECTION_TROUBLESHOOTING.md`
   - Check Xcode console for detailed logs
   - Test backend with `curl http://YOUR_MAC_IP:8000`

## Additional Resources

- **In-App Help**: Server Settings → Setup Guide
- **Detailed Guide**: `CONNECTION_TROUBLESHOOTING.md`
- **Network Status**: Network Diagnostics view
- **Console Logs**: Xcode console shows 🔐 ✅ ❌ symbols

## Questions?

When asking for help, provide:
1. Device type (Simulator or iPhone model)
2. Mac's IP address
3. Connection test results from app
4. Xcode console logs (especially lines with 🔌 ❌ symbols)

---

**TL;DR**: 
- Fixed port mismatch (8001 → 8000)
- Made timeouts faster (60s → 15s)
- Added 3 new debugging views
- Use "Server Settings" on login to configure and test
