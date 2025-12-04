# Quick Start Guide - Fix Connection Timeout

## 🚀 Super Quick Fix (3 Steps)

### Step 1: Find Your Mac's IP
Open Terminal and run:
```bash
ipconfig getifaddr en0
```
You'll see something like: `192.168.1.100` ← This is your IP!

### Step 2: Configure the App
1. Open CodeCheck on your iPhone
2. Tap **"Server Settings"** (gear icon on login screen)
3. Enable **"Use Custom Server"**
4. Type: `http://192.168.1.100:8000` (use your IP from Step 1)
5. Tap **"Save Server URL"**

### Step 3: Test It
1. Tap **"Test Connection"**
2. Should say "✅ Connected!" within 15 seconds
3. If yes → **Done!** Try logging in
4. If no → See troubleshooting below

---

## ⚠️ Most Common Issues

### Issue 1: "Cannot Connect to Host"
**Fix**: Make sure your backend is running!
```bash
# In your backend directory, you should see:
Server running on http://0.0.0.0:8000
```

### Issue 2: Still timing out
**Fix**: Check you're on WiFi (not cellular)
1. Open app → Server Settings → Network Diagnostics
2. Must say "Connection Type: WiFi"
3. If it says "Cellular" → Turn off cellular, connect to WiFi

### Issue 3: Wrong port
**Fix**: Both services now use port 8000
- If your backend uses a different port, update the URL
- Example: `http://192.168.1.100:5000` for port 5000

---

## 📱 Device-Specific Instructions

### For iOS Simulator:
**No changes needed!** Default works automatically:
- Uses: `http://localhost:8000`
- Just make sure backend is running

### For Physical iPhone:
**Must configure IP address:**
1. Find Mac's IP: `ipconfig getifaddr en0`
2. Set in app: `http://YOUR_IP:8000`
3. Both devices on same WiFi

---

## 🔍 New Features You Can Use

### 1. Connection Test
**Location**: Server Settings → Test Connection
**What it does**: Tests if app can reach your backend
**Time**: ~5-15 seconds
**Shows**: Detailed error messages if it fails

### 2. Network Diagnostics  
**Location**: Server Settings → Network Diagnostics
**What it does**: Shows real-time network status
**Checks**: WiFi vs Cellular, connection status
**Helpful**: Verify you're on WiFi

### 3. Quick Presets
**Location**: Server Settings → Quick Presets
**Options**:
- Simulator (localhost)
- Physical Device (configurable IP)
- Local Network (custom)

---

## ✅ Verification Checklist

Before testing, verify:

- [ ] Backend server is running (check terminal)
- [ ] Backend is on port **8000** (not 8001)
- [ ] iPhone is on **WiFi** (not cellular)
- [ ] Mac and iPhone on **same WiFi network**
- [ ] Server URL in app is correct
- [ ] Server URL has `http://` prefix
- [ ] No typos in IP address

---

## 🔧 What I Fixed in Your Code

### Fixed Files:

1. **AuthService.swift**
   - Reduced timeout: 60s → 15s (line ~32)
   - Faster failure detection

2. **CodeLookupService.swift**  
   - Changed port: 8001 → 8000 (line ~14)
   - Now matches AuthService
   - Reduced timeout: 30s → 15s

3. **AuthView.swift**
   - Updated to use new DeveloperSettingsView (line ~159)

### New Files:

1. **DeveloperSettingsView.swift** - Server configuration UI
2. **ConnectionTestView.swift** - Connection testing tool
3. **NetworkDiagnosticsView.swift** - Network status monitor
4. **CONNECTION_TROUBLESHOOTING.md** - Full guide
5. **FIXES_SUMMARY.md** - What changed

---

## 🎯 Testing Your Fix

### Test 1: Quick Connection Test (15 seconds)
```
1. Open app
2. Tap "Server Settings"
3. Tap "Test Connection"
4. Should succeed < 15 seconds
```

### Test 2: Full App Test (2 minutes)
```
1. Connection test ✓
2. Network diagnostics ✓
3. Login ✓
4. Try a feature ✓
```

---

## 💡 Pro Tips

### Tip 1: Check Logs
Xcode console shows helpful symbols:
- 🔐 = Authentication attempt
- ✅ = Success
- ❌ = Error
- 🔌 = Connection test

### Tip 2: Test Backend Separately
```bash
# Test if backend responds
curl http://YOUR_MAC_IP:8000

# Should see HTML or JSON response
```

### Tip 3: Use Network Diagnostics
Real-time view shows:
- Network status
- Connection type (must be WiFi)
- Device info

---

## 🆘 Still Not Working?

### Try This:
1. Restart backend server
2. Restart iPhone
3. Forget and rejoin WiFi network
4. Check Mac firewall (System Settings → Network → Firewall)
5. Try `http://` not `https://`

### Check These:
```bash
# Is backend listening?
lsof -i :8000

# What's your IP?
ifconfig | grep "inet "

# Can you reach it locally?
curl http://localhost:8000
```

### Get Help:
When asking for help, share:
1. iPhone model
2. iOS version  
3. Mac's IP address
4. Connection test result screenshot
5. Xcode console output

---

## 📚 More Information

- **Detailed Guide**: Read `CONNECTION_TROUBLESHOOTING.md`
- **Changes Made**: Read `FIXES_SUMMARY.md`
- **In-App Help**: Server Settings → Setup Guide

---

## TL;DR

```bash
# 1. Get your Mac's IP
ipconfig getifaddr en0

# 2. In app: Server Settings
# 3. Use Custom Server: http://YOUR_IP:8000
# 4. Test Connection
# 5. Done! ✅
```

**That's it!** The connection should now work within 15 seconds instead of timing out.
