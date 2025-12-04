# CodeCheck iOS - Connection Troubleshooting Guide

## Overview
This guide helps you fix connection timeout issues when running the CodeCheck app on your iPhone.

## Changes Made

### 1. **Fixed Port Mismatch** ✅
- **Issue**: AuthService was using port 8000, but CodeLookupService was using port 8001
- **Fix**: Both services now use port **8000** consistently
- **Location**: `CodeLookupService.swift`

### 2. **Reduced Timeout Intervals** ✅
- **Issue**: Long timeouts (60 seconds) made debugging slow
- **Fix**: Reduced to 15 seconds for requests, 30 seconds for resources
- **Location**: `AuthService.swift` and `CodeLookupService.swift`

### 3. **Added Connection Testing Tools** ✅
- **New File**: `ConnectionTestView.swift` - Visual connection tester
- **New File**: `DeveloperSettingsView.swift` - Easy server URL configuration
- **Access**: Tap "Server Settings" button on the login screen

## Quick Fix Checklist

### Step 1: Verify Your Backend is Running
```bash
# In your backend directory, make sure the server is running
# It should say something like "Server running on http://0.0.0.0:8000"
```

### Step 2: Find Your Mac's IP Address
**Option A - System Settings:**
1. Open System Settings → Network
2. Select your WiFi connection
3. Look for "IP Address" (e.g., `192.168.1.100`)

**Option B - Terminal:**
```bash
# Run this command in Terminal:
ipconfig getifaddr en0

# Output will be your IP (e.g., 192.168.1.100)
```

### Step 3: Update Your App Configuration

**For iOS Simulator:**
- ✅ Default is `http://localhost:8000` - No change needed!

**For Physical iPhone:**
1. Open the app
2. Tap "Server Settings" on login screen
3. Choose "Use Custom Server"
4. Enter: `http://YOUR_MAC_IP:8000` (replace YOUR_MAC_IP with actual IP)
5. Tap "Save Server URL"

**Or use the Quick Presets:**
- Tap "Physical Device (10.0.0.214)" if that's your Mac's IP
- Or manually enter your Mac's IP address

### Step 4: Test Connection
1. In Developer Settings, tap "Test Connection"
2. Read the test results
3. Follow the troubleshooting tips if connection fails

## Common Issues & Solutions

### ❌ "Cannot Connect to Host"
**Possible Causes:**
- Backend server is not running
- Wrong IP address
- Device not on same network as Mac

**Solutions:**
1. Start your backend server
2. Verify IP address matches your Mac
3. Ensure iPhone and Mac are on the same WiFi network

### ❌ "Connection Timed Out"
**Possible Causes:**
- Server is running but too slow or hung
- Firewall blocking connection
- Network connectivity issues

**Solutions:**
1. Restart your backend server
2. Check Mac Firewall: System Settings → Network → Firewall
3. Try a different WiFi network

### ❌ "Cannot Find Host"
**Possible Causes:**
- Invalid hostname or IP address
- DNS resolution issue

**Solutions:**
- Use IP address instead of hostname
- Verify the IP address is correct

### ❌ "App Transport Security Blocking"
**Issue**: iOS blocks HTTP connections by default

**Solution**: Ensure your `Info.plist` has this configuration:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

## Network Requirements

### Same WiFi Network
- ✅ Mac and iPhone **must** be on the same WiFi
- ❌ Won't work with cellular data or different networks
- ❌ Won't work if Mac is on ethernet and iPhone on WiFi (different subnets)

### Firewall Settings
Check that your Mac firewall allows incoming connections:
1. System Settings → Network → Firewall
2. If firewall is on, click "Options"
3. Make sure your backend app isn't blocked

## Testing Your Setup

### Method 1: Use Built-in Connection Test
1. Open CodeCheck app
2. Tap "Server Settings" on login
3. Tap "Test Connection"
4. Read the detailed results

### Method 2: Test from iPhone Safari
1. Open Safari on your iPhone
2. Navigate to: `http://YOUR_MAC_IP:8000`
3. You should see a response from your backend

### Method 3: Test from Terminal on Mac
```bash
# Test if your server responds to network requests
curl http://localhost:8000

# Test from your Mac's IP (as iPhone would see it)
curl http://YOUR_MAC_IP:8000
```

## Advanced Configuration

### Using a Custom Server URL
If you want to use a different server (staging, production, etc.):

1. Tap "Server Settings" on login screen
2. Enable "Use Custom Server"
3. Enter your server URL (e.g., `https://api.myserver.com`)
4. Tap "Save Server URL"

### Switching Between Environments
The app automatically uses the right URL:
- **Simulator**: `http://localhost:8000`
- **Physical Device**: `http://10.0.0.214:8000` (or your custom IP)

## Code Changes Summary

### AuthService.swift
```swift
// ✅ Timeout reduced from 60s to 15s
configuration.timeoutIntervalForRequest = 15
configuration.timeoutIntervalForResource = 30
```

### CodeLookupService.swift
```swift
// ✅ Now matches AuthService configuration
// ✅ Port changed from 8001 to 8000
self.baseURL = "http://10.0.0.214:8000"  // Changed from port 8001 to 8000
```

## Still Having Issues?

### Enable Detailed Logging
The app already prints detailed connection logs. Check Xcode console for:
- 🔐 Login attempts
- ✅ Successful connections
- ❌ Error details
- 🔌 Connection test results

### Network Debugging Commands
```bash
# Check if port 8000 is listening on your Mac
lsof -i :8000

# Check your Mac's IP addresses
ifconfig | grep "inet "

# Ping your Mac from Terminal (to verify network)
ping YOUR_MAC_IP
```

## Getting Help

When asking for help, provide:
1. Device type (Simulator or Physical iPhone model)
2. Mac's IP address
3. Backend server logs
4. Connection test results from the app
5. Any error messages from Xcode console

## Quick Reference

| Scenario | Server URL to Use |
|----------|------------------|
| Testing in iOS Simulator | `http://localhost:8000` |
| Testing on physical iPhone | `http://YOUR_MAC_IP:8000` |
| Production/Remote Server | `https://your-server.com` |

## Notes

- The default IP `10.0.0.214` in the code is just an example - **you must update it** to match your Mac's actual IP
- Server URLs must include the port number (`:8000`) unless using standard HTTP/HTTPS ports
- Always use `http://` for local development (not `https://`)
- Make sure there are no spaces in the URL
