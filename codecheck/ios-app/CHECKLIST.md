# Connection Troubleshooting Checklist

## Pre-Flight Checklist
Use this checklist before running your app on a physical iPhone.

---

### ✅ Backend Server
- [ ] Backend server is running
- [ ] Server shows "running on port 8000" (or your chosen port)
- [ ] No error messages in backend console
- [ ] Backend responds to: `curl http://localhost:8000`

---

### ✅ Network Configuration
- [ ] iPhone is connected to WiFi (not cellular)
- [ ] Mac is connected to same WiFi network
- [ ] WiFi is not a guest or isolated network
- [ ] Found Mac's IP address using `ipconfig getifaddr en0`

---

### ✅ App Configuration
- [ ] Opened Server Settings in the app
- [ ] Enabled "Use Custom Server"
- [ ] Entered: `http://YOUR_MAC_IP:8000`
- [ ] Saved the server URL
- [ ] URL has `http://` prefix (not `https://`)
- [ ] No spaces or typos in the URL
- [ ] Port number is correct (8000 by default)

---

### ✅ Connection Test
- [ ] Ran "Test Connection" in the app
- [ ] Test completed in < 15 seconds
- [ ] Test result shows "✅ Connected!"
- [ ] No error messages shown

---

### ✅ Network Diagnostics
- [ ] Opened "Network Diagnostics" in the app
- [ ] Network Status: ✅ Connected
- [ ] Connection Type: WiFi (not Cellular)
- [ ] Low Cost Network: ✅ Yes

---

### ✅ Firewall & Security
- [ ] Mac firewall allows incoming connections (if enabled)
- [ ] No VPN running that might block local network
- [ ] App Transport Security configured (for HTTP)

---

## If Connection Test Fails

### Error: "Cannot Connect to Host"
- [ ] Backend is definitely running?
- [ ] Checked backend console for startup messages?
- [ ] Verified IP address is correct?
- [ ] Both devices on same WiFi?
- [ ] Tried restarting backend server?

### Error: "Connection Timed Out"
- [ ] Checked Mac firewall settings?
- [ ] Backend is responding (test with curl)?
- [ ] Network is stable (not intermittent)?
- [ ] Tried forgetting and rejoining WiFi?

### Error: "Cannot Find Host"
- [ ] Using IP address (not hostname)?
- [ ] No typos in the URL?
- [ ] Format is: `http://192.168.1.XXX:8000`?
- [ ] Tried pinging Mac from another device?

---

## Quick Tests

### Test 1: Backend is Running
```bash
# In terminal on Mac
curl http://localhost:8000
# Should see response
```

### Test 2: Backend Accepts Network Requests  
```bash
# In terminal on Mac (use your actual IP)
curl http://192.168.1.100:8000
# Should see same response
```

### Test 3: iPhone Can Reach Mac
```bash
# Open Safari on iPhone
# Navigate to: http://YOUR_MAC_IP:8000
# Should see backend response
```

---

## Environment-Specific

### iOS Simulator
- [ ] Using default URL: `http://localhost:8000`
- [ ] No custom server configuration needed
- [ ] Backend running on Mac

### Physical iPhone
- [ ] Found Mac's real IP address
- [ ] Configured custom server URL
- [ ] Format: `http://192.168.1.XXX:8000`
- [ ] Both on same WiFi

---

## Verification Commands

Run these on your Mac to verify setup:

```bash
# 1. What's my IP address?
ipconfig getifaddr en0

# 2. Is backend listening on port 8000?
lsof -i :8000

# 3. Can I reach my backend locally?
curl http://localhost:8000

# 4. Can I reach it via IP?
curl http://$(ipconfig getifaddr en0):8000

# 5. What networks am I connected to?
networksetup -listallhardwareports
```

---

## Common Mistakes

❌ **Using wrong port**
- AuthService was on 8000
- CodeLookupService was on 8001
- ✅ **Fixed**: Both now use 8000

❌ **Using https:// for local server**
- Local servers typically use HTTP
- ✅ **Fixed**: Use `http://` not `https://`

❌ **iPhone on cellular, not WiFi**
- Cannot reach local network over cellular
- ✅ **Fixed**: Connect to WiFi

❌ **Different WiFi networks**
- Mac on one network, iPhone on another
- ✅ **Fixed**: Connect to same network

❌ **Wrong IP address**
- Using old or incorrect IP
- ✅ **Fixed**: Run `ipconfig getifaddr en0` to get current IP

❌ **Backend not running**
- Forgot to start server
- ✅ **Fixed**: Check terminal for "Server running..." message

---

## Success Criteria

You should see ALL of these:

### In the App:
✅ Connection Test shows "Connected!"
✅ Network Diagnostics shows WiFi
✅ Test completes in < 15 seconds
✅ Can log in successfully
✅ Features work (code lookup, etc.)

### In Backend Console:
✅ Shows incoming requests from 192.168.1.XXX
✅ Returns 200 status codes
✅ No error messages

### In Xcode Console:
✅ Shows "🔐 Attempting login to: http://..."
✅ Shows "✅ Login successful" or "✅ Connection successful"
✅ No "❌ Network error" messages

---

## After Successful Connection

### Save Your Configuration
- [ ] Note your Mac's IP: ________________
- [ ] Note the port used: ________________
- [ ] Server URL format: ________________

### Remember:
- Mac's IP may change (especially on different networks)
- Need to update app if IP changes
- Simulator always uses localhost (doesn't change)

---

## Need Help?

### Information to Provide:
1. Device: [ ] Simulator  [ ] iPhone (model: _______)
2. iOS Version: _______________
3. Mac IP Address: _______________
4. Backend Port: _______________
5. Connection Test Result: _______________
6. Network Diagnostics Result: _______________
7. Xcode Console Errors: _______________

### Attach:
- Screenshot of Connection Test result
- Screenshot of Network Diagnostics
- Xcode console output (last 20-30 lines)
- Backend console output

---

## Notes Section
Use this space for your specific setup details:

```
My Mac's IP: ____________________

WiFi Network Name: ____________________

Backend Port: ____________________

Custom Configuration Notes:
_______________________________________________
_______________________________________________
_______________________________________________
```

---

**Last Updated**: 2025-12-01
**App Version**: CodeCheck iOS v1.0
**Documentation**: See CONNECTION_TROUBLESHOOTING.md for details
